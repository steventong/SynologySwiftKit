
import Foundation

// MARK: - ConnectionChecker

/// 连接检查器（依赖注入）
/// Connection checker (dependency injection)
final class ConnectionChecker: ConnectionChecking {
    // MARK: - Dependencies

    private let apiClient: ConnectionStateProviding & ConnectionStateUpdating
    private let quickConnectApi: QuickConnectClient
    private let pingpong: PingPongProviding
    private let keyChainStorage: any SensitiveStorage

    // MARK: - Initialization

    /// 初始化连接检查器 (直接注入所有依赖)
    /// Initialize connection checker (inject all dependencies directly)
    init(apiClient: ConnectionStateProviding & ConnectionStateUpdating, quickConnectApi: QuickConnectClient, pingpong: PingPongProviding, keyChainStorage: any SensitiveStorage = StorageService()) {
        self.apiClient = apiClient
        self.quickConnectApi = quickConnectApi
        self.pingpong = pingpong
        self.keyChainStorage = keyChainStorage
    }

    // MARK: - Connection Status Check (AsyncStream)

    /// 检查当前连接状态（AsyncStream 版本）
    /// Check current connection status with AsyncStream
    /// - Returns: AsyncStream 返回连接检查进度
    func check() -> AsyncStream<ConnectionCheckProgress> {
        makeCheckStream { [self] in
            guard let credentials = self.keyChainStorage.getCredentials() else {
                throw SynologyError.network(message: "Connection unreachable and no saved credentials")
            }

            return ConnectionCheckRequest(
                originalServer: credentials.server,
                attempts: [
                    try LoginServerAddressResolver.fixedAttempt(
                        for: credentials.server,
                        usesHTTPS: credentials.usesHTTPS
                    ),
                ]
            )
        }
    }

    /// 自动识别协议并优先尝试 HTTPS。
    /// Automatically resolve the protocol with HTTPS preferred.
    func check(server: String) -> AsyncStream<ConnectionCheckProgress> {
        makeCheckStream {
            ConnectionCheckRequest(
                originalServer: server,
                attempts: try LoginServerAddressResolver.automaticAttempts(for: server)
            )
        }
    }

    /// 检查当前连接状态（AsyncStream 版本）
    /// Check current connection status with AsyncStream
    /// - Returns: AsyncStream 返回连接检查进度
    func check(server: String, usesHTTPS: Bool) -> AsyncStream<ConnectionCheckProgress> {
        makeCheckStream {
            ConnectionCheckRequest(
                originalServer: server,
                attempts: [
                    try LoginServerAddressResolver.fixedAttempt(
                        for: server,
                        usesHTTPS: usesHTTPS
                    ),
                ]
            )
        }
    }
}

// MARK: - Private Support

private extension ConnectionChecker {
    struct ConnectionCheckRequest {
        let originalServer: String
        let attempts: [LoginConnectionAttempt]
    }

    func makeCheckStream(
        requestBuilder: @escaping @Sendable () throws -> ConnectionCheckRequest
    ) -> AsyncStream<ConnectionCheckProgress> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    let request = try requestBuilder()
                    await self.performConnectionCheck(request: request, continuation: continuation)
                } catch {
                    Logger.error("ConnectionChecker#check, setup failed: \(error)")
                    finish(continuation, with: .failed(message: error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 执行连接检查的内部方法
    /// Internal method to perform connection check
    private func performConnectionCheck(
        request: ConnectionCheckRequest,
        continuation: AsyncStream<ConnectionCheckProgress>.Continuation
    ) async {
        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        continuation.yield(.checking)

        do {
            try Task.checkCancellation()

            var lastError: Error = SynologyError.network(message: "Connection resolution failed")
            for attempt in request.attempts {
                do {
                    if let cachedConnection = try await reachableCachedConnection(
                        originalServer: request.originalServer,
                        attempt: attempt
                    ) {
                        Logger.info("ConnectionChecker#check, using reachable cached url: \(cachedConnection.url)")
                        finish(continuation, with: .success(connection: cachedConnection, usedCachedConnection: true))
                        return
                    }

                    let isQuickConnect = QuickConnectUtils.isQuickConnectId(server: attempt.server)
                    let newConn = try await resolveAvailableConnection(
                        server: attempt.server,
                        usesHTTPS: attempt.usesHTTPS
                    )
                    try Task.checkCancellation()

                    if !isQuickConnect, !(try await pingpong.pingpong(url: newConn.url)) {
                        throw SynologyError.network(message: "Refreshed connection unreachable")
                    }
                    try Task.checkCancellation()

                    Logger.info("ConnectionChecker#check, resolved reachable connection candidate: \(newConn.url)")
                    finish(continuation, with: .success(connection: newConn, usedCachedConnection: false))
                    return
                } catch let SynologyError.serverCertificateUntrusted(certificate) {
                    finish(continuation, with: .serverCertificateUntrusted(certificate))
                    return
                } catch {
                    lastError = error
                    Logger.info(
                        "ConnectionChecker#check, candidate unavailable: \(attempt.server), error: \(error.localizedDescription)"
                    )
                }
            }
            throw lastError
        } catch is CancellationError {
            continuation.finish()
        } catch {
            Logger.error("ConnectionChecker#check, connection check failed: \(error)")
            finish(continuation, with: .failed(message: error.localizedDescription))
        }
    }

    func reachableCachedConnection(
        originalServer: String,
        attempt: LoginConnectionAttempt
    ) async throws -> SynologyConnection? {
        guard let credentials = keyChainStorage.getCredentials(),
              normalizedServer(credentials.server) == normalizedServer(originalServer),
              credentials.usesHTTPS == attempt.usesHTTPS,
              let currentConn = apiClient.connection
        else {
            return nil
        }

        guard try await pingpong.pingpong(url: currentConn.url) else {
            return nil
        }
        return SynologyConnection(type: currentConn.type, url: currentConn.url)
    }

    func normalizedServer(_ server: String) -> String {
        server
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }

    /// 解析可用连接（封装 Ping 测试、QuickConnect 解析、AudioStation 验证等逻辑）
    /// Resolve available connection (encapsulates Ping test, QuickConnect resolution, AudioStation verification)
    private func resolveAvailableConnection(server: String, usesHTTPS: Bool) async throws -> SynologyConnection {
        if !QuickConnectUtils.isQuickConnectId(server: server) {
            return SynologyConnection(type: .custom_domain, url: server)
        }

        Logger.info("ConnectionChecker#resolveAvailableConnection, resolving via QuickConnect for \(server)")
        do {
            return try await quickConnectApi.getDeviceConnection(
                quickConnectId: server,
                usesHTTPS: usesHTTPS
            )
        } catch {
            Logger.error("ConnectionChecker#resolveAvailableConnection, QuickConnect failed: \(error)")
            throw error
        }
    }

    func finish(
        _ continuation: AsyncStream<ConnectionCheckProgress>.Continuation,
        with progress: ConnectionCheckProgress
    ) {
        continuation.yield(progress)
        continuation.finish()
    }
}
