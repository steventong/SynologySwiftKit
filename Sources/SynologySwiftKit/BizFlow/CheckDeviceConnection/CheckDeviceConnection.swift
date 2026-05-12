
import Foundation

// MARK: - CheckDeviceConnection

/// 设备连接检查类（依赖注入）
/// Device connection checker (dependency injection)
final class CheckDeviceConnection: CheckDeviceConnectionProviding {
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
    func checkConnectionStatus() -> AsyncStream<CheckDeviceConnectionProgress> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    guard let credentials = keyChainStorage.getCredentials() else {
                        throw SynologyError.network(message: "Connection unreachable and no saved credentials")
                    }

                    let server = credentials.server
                    let usesHTTPS = credentials.usesHTTPS
                    await self.performConnectionCheck(server: server, usesHTTPS: usesHTTPS, continuation: continuation)
                } catch {
                    Logger.error("CheckDeviceConnection#checkConnectionStatus, setup failed: \(error)")
                    continuation.yield(.failed(message: error.localizedDescription))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 检查当前连接状态（AsyncStream 版本）
    /// Check current connection status with AsyncStream
    /// - Returns: AsyncStream 返回连接检查进度
    func checkConnectionStatus(server: String, usesHTTPS: Bool) -> AsyncStream<CheckDeviceConnectionProgress> {
        AsyncStream { continuation in
            let task = Task {
                await self.performConnectionCheck(server: server, usesHTTPS: usesHTTPS, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Private Support

private extension CheckDeviceConnection {
    /// 执行连接检查的内部方法
    /// Internal method to perform connection check
    private func performConnectionCheck(server: String, usesHTTPS: Bool, continuation: AsyncStream<CheckDeviceConnectionProgress>.Continuation) async {
        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        continuation.yield(.checking)

        do {
            try Task.checkCancellation()

            // 如果连接信息存在，测试简单 Ping 检查
            if let currentConn = apiClient.connection, await pingpong.pingpong(url: currentConn.url) {
                try Task.checkCancellation()

                // Success
                Logger.info("CheckDeviceConnection#checkConnectionStatus, checking current url: \(currentConn.url)")
                let cachedConnection = SynologyConnection(type: currentConn.type, url: currentConn.url)
                continuation.yield(.success(connection: cachedConnection, usedCachedConnection: true))
                continuation.finish()
                return
            }

            // 获取新的地址 - quickconnectid
            let newConn = try await resolveAvailableConnection(server: server, usesHTTPS: usesHTTPS)
            try Task.checkCancellation()

            // 新地址 pingpong 检查
            guard await pingpong.pingpong(url: newConn.url) else {
                throw SynologyError.network(message: "Refreshed connection unreachable")
            }
            try Task.checkCancellation()

            // 更新 ApiClient 连接状态 (Update ApiClient connection status)
            // 保存可用地址 (Save available address to Keychain)
            saveConnection(url: newConn.url, type: newConn.type)

            Logger.info("CheckDeviceConnection#checkConnectionStatus, connection refreshed: \(newConn.url)")
            continuation.yield(.success(connection: newConn, usedCachedConnection: false))
            continuation.finish()
            return
        } catch is CancellationError {
            continuation.finish()
        } catch {
            Logger.error("CheckDeviceConnection#checkConnectionStatus, connection check failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
        }
    }

    /// 解析可用连接（封装 Ping 测试、QuickConnect 解析、AudioStation 验证等逻辑）
    /// Resolve available connection (encapsulates Ping test, QuickConnect resolution, AudioStation verification)
    private func resolveAvailableConnection(server: String, usesHTTPS: Bool) async throws -> SynologyConnection {
        // 1. 检查是否为 QuickConnect ID
        if !QuickConnectUtils.isQuickConnectId(server: server) {
            // 自定义域名/IP，直接返回
            // Custom domain/IP, return directly
            // 可选：在此处做 Ping 检查以确保地址有效
            // Optional: Do ping check here to ensure address is valid
            return SynologyConnection(type: .custom_domain, url: server)
        }

        // 2. 通过 QuickConnect 解析
        // Resolve via QuickConnect
        Logger.info("CheckDeviceConnection#resolveAvailableConnection, resolving via QuickConnect for \(server)")
        do {
            let connection = try await quickConnectApi.getDeviceConnection(quickConnectId: server, usesHTTPS: usesHTTPS)
            return connection
        } catch {
            Logger.error("CheckDeviceConnection#resolveAvailableConnection, QuickConnect failed: \(error)")
            throw error
        }
    }
}

private extension CheckDeviceConnection {
    private func saveConnection(url: String, type: ConnectionType) {
        // 更新 ApiClient 连接状态 (Update ApiClient connection status)
        apiClient.updateConnection(type: type, url: url)
        // 保存可用地址 (Save available address to Keychain)
        keyChainStorage.saveConnectionInfo(url: url, typeString: type.rawValue)
    }
}
