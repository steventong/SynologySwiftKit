
import Foundation

// MARK: - CheckDeviceConnection

/// 设备连接检查类（依赖注入）
/// Device connection checker (dependency injection)
public class CheckDeviceConnection: CheckDeviceConnectionProviding {
    // MARK: - Dependencies

    private let apiClient: ApiClientProviding
    private let apiInfoApi: ApiInfoProviding
    private let quickConnectApi: QuickConnectApi
    private let audioStationApi: AudioStationApi
    private let pingpong: PingPongProviding
    private let keyChainStorage: KeyChainStorage

    // MARK: - Initialization

    /// 初始化连接检查器 (直接注入所有依赖)
    /// Initialize connection checker (inject all dependencies directly)
    public init(apiClient: ApiClientProviding, apiInfoApi: ApiInfoProviding, quickConnectApi: QuickConnectApi, audioStationApi: AudioStationApi, pingpong: PingPongProviding, keyChainStorage: KeyChainStorage = KeyChainStorage()) {
        self.apiClient = apiClient
        self.apiInfoApi = apiInfoApi
        self.quickConnectApi = quickConnectApi
        self.pingpong = pingpong
        self.audioStationApi = audioStationApi
        self.keyChainStorage = keyChainStorage
    }

    // MARK: - Connection Status Check (AsyncStream)

    /// 检查当前连接状态（AsyncStream 版本）
    /// Check current connection status with AsyncStream
    /// - Returns: AsyncStream 返回连接检查进度
    public func checkConnectionStatus() -> AsyncStream<CheckDeviceConnectionProgress> {
        AsyncStream { continuation in
            Task {
                guard let credentials = keyChainStorage.getCredentials() else {
                    throw SynologyError.network(message: "Connection unreachable and no saved credentials")
                }

                let server = credentials.server
                let isEnableHttps = credentials.isEnableHttps ?? false
                await self.performConnectionCheck(server: server, isHttps: isEnableHttps, continuation: continuation)
            }
        }
    }

    /// 检查当前连接状态（AsyncStream 版本）
    /// Check current connection status with AsyncStream
    /// - Returns: AsyncStream 返回连接检查进度
    public func checkConnectionStatus(server: String, isHttps: Bool) -> AsyncStream<CheckDeviceConnectionProgress> {
        AsyncStream { continuation in
            Task {
                await self.performConnectionCheck(server: server, isHttps: isHttps, continuation: continuation)
            }
        }
    }
}

// MARK: - Private Support

private extension CheckDeviceConnection {
    /// 执行连接检查的内部方法
    /// Internal method to perform connection check
    private func performConnectionCheck(server: String, isHttps: Bool, continuation: AsyncStream<CheckDeviceConnectionProgress>.Continuation) async {
        continuation.yield(.checking)

        do {
            // 如果连接信息存在，测试简单 Ping 检查
            if let currentConn = apiClient.connection, await pingpong.pingpong(url: currentConn.url) {
                // Success
                Logger.info("CheckDeviceConnection#checkConnectionStatus, checking current url: \(currentConn.url)")
                /// cached 表示不需要再次登录用户。
                /// cached = false 表示地址切换了，需要重新登录的。
                continuation.yield(.success(type: currentConn.type, url: currentConn.url, cached: true))
                continuation.finish()
                return
            }

            // 获取新的地址 - quickconnectid
            let resolved = try await resolveAvailableConnection(server: server, enableHttps: isHttps)

            guard await pingpong.pingpong(url: resolved.url) else {
                throw SynologyError.network(message: "Refreshed connection unreachable")
            }

            // 更新 ApiClient 连接状态 (Update ApiClient connection status)
            apiClient.updateConnection(type: resolved.type, url: resolved.url)
            // 保存可用地址 (Save available address to Keychain)
            keyChainStorage.saveConnectionInfo(url: resolved.url, typeString: resolved.type.rawValue)

            Logger.info("CheckDeviceConnection#checkConnectionStatus, connection refreshed: \(resolved.url)")
            continuation.yield(.success(type: resolved.type, url: resolved.url, cached: false))
            continuation.finish()
            return
        } catch {
            Logger.error("CheckDeviceConnection#checkConnectionStatus, connection check failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
        }
    }

    /// 解析可用连接（封装 Ping 测试、QuickConnect 解析、AudioStation 验证等逻辑）
    /// Resolve available connection (encapsulates Ping test, QuickConnect resolution, AudioStation verification)
    private func resolveAvailableConnection(server: String, enableHttps: Bool) async throws -> (type: ConnectionType, url: String) {
        // 1. 检查是否为 QuickConnect ID
        if !QuickConnectUtils.isQuickConnectId(server: server) {
            // 自定义域名/IP，直接返回
            // Custom domain/IP, return directly
            // 可选：在此处做 Ping 检查以确保地址有效
            // Optional: Do ping check here to ensure address is valid
            return (.custom_domain, server)
        }

        // 2. 通过 QuickConnect 解析
        // Resolve via QuickConnect
        Logger.info("CheckDeviceConnection#resolveAvailableConnection, resolving via QuickConnect for \(server)")
        do {
            let connection = try await quickConnectApi.getDeviceConnection(quickConnectId: server, enableHttps: enableHttps)
            return (connection.type, connection.url)
        } catch {
            Logger.error("CheckDeviceConnection#resolveAvailableConnection, QuickConnect failed: \(error)")
            throw error
        }
    }
}
