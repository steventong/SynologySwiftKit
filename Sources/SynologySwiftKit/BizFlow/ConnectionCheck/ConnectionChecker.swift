
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

            return ConnectionCheckRequest(server: credentials.server, usesHTTPS: credentials.usesHTTPS)
        }
    }

    /// 检查当前连接状态（AsyncStream 版本）
    /// Check current connection status with AsyncStream
    /// - Returns: AsyncStream 返回连接检查进度
    func check(server: String, usesHTTPS: Bool) -> AsyncStream<ConnectionCheckProgress> {
        makeCheckStream {
            ConnectionCheckRequest(server: server, usesHTTPS: usesHTTPS)
        }
    }
}

// MARK: - Private Support

private extension ConnectionChecker {
    struct ConnectionCheckRequest {
        let server: String
        let usesHTTPS: Bool
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

            if let cachedConnection = await reachableCachedConnection() {
                Logger.info("ConnectionChecker#check, using reachable cached url: \(cachedConnection.url)")
                finish(continuation, with: .success(connection: cachedConnection, usedCachedConnection: true))
                return
            }

            let newConn = try await resolveAvailableConnection(
                server: request.server,
                usesHTTPS: request.usesHTTPS
            )
            try Task.checkCancellation()

            guard await pingpong.pingpong(url: newConn.url) else {
                throw SynologyError.network(message: "Refreshed connection unreachable")
            }
            try Task.checkCancellation()

            Logger.info("ConnectionChecker#check, resolved reachable connection candidate: \(newConn.url)")
            finish(continuation, with: .success(connection: newConn, usedCachedConnection: false))
        } catch is CancellationError {
            continuation.finish()
        } catch {
            Logger.error("ConnectionChecker#check, connection check failed: \(error)")
            finish(continuation, with: .failed(message: error.localizedDescription))
        }
    }

    func reachableCachedConnection() async -> SynologyConnection? {
        guard let currentConn = apiClient.connection,
              await pingpong.pingpong(url: currentConn.url)
        else {
            return nil
        }

        return SynologyConnection(type: currentConn.type, url: currentConn.url)
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
