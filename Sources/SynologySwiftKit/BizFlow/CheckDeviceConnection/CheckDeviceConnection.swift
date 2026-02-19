
import Foundation

// MARK: - CheckDeviceConnection

/// 设备连接检查类（依赖注入）
/// Device connection checker (dependency injection)
public class CheckDeviceConnection {
    // MARK: - Dependencies

    private let apiClient: ApiClientProviding
    private let apiInfoApi: ApiInfoProviding
    private let quickConnectApi: QuickConnectApi
    private let pingpong: PingPongProviding
    private let audioStationApi: AudioStationApi

    // MARK: - Initialization

    /// 初始化连接检查器 (直接注入所有依赖)
    /// Initialize connection checker (inject all dependencies directly)
    public init(apiClient: ApiClientProviding, apiInfoApi: ApiInfoProviding, quickConnectApi: QuickConnectApi, pingpong: PingPongProviding, audioStationApi: AudioStationApi) {
        self.apiClient = apiClient
        self.apiInfoApi = apiInfoApi
        self.quickConnectApi = quickConnectApi
        self.pingpong = pingpong
        self.audioStationApi = audioStationApi
    }

    // MARK: - Connection Status Check (AsyncStream)

    /// 检查当前连接状态（AsyncStream 版本）
    /// Check current connection status with AsyncStream
    /// - Parameter fetchNewServerByQuickConnectId: 是否通过 QuickConnect ID 获取新服务器地址
    /// - Returns: AsyncStream 返回连接检查进度
    public func checkConnectionStatus(fetchNewConnectionUrl: Bool) -> AsyncStream<ConnectionCheckProgress> {
        AsyncStream { continuation in
            Task {
                await self.performConnectionCheck(fetchNewConnectionUrl: fetchNewConnectionUrl, continuation: continuation)
            }
        }
    }
}

// MARK: - Private Support

private extension CheckDeviceConnection {
    /// 执行连接检查的内部方法
    /// Internal method to perform connection check
    func performConnectionCheck(fetchNewConnectionUrl: Bool,
                                continuation: AsyncStream<ConnectionCheckProgress>.Continuation) async {
        continuation.yield(.checking)

        do {
            // 检查 apiClient 是否有当前连接
            guard let current = apiClient.currentConnection else {
                throw SynologyError.network(message: "No active connection to check")
            }

            Logger.info("CheckDeviceConnection#checkConnectionStatus, checking current url: \(current.url)")

            // 简单 Ping 检查
            if await pingpong.pingpong(url: current.url) {
                // Success
                Logger.info("CheckDeviceConnection#checkConnectionStatus, connection OK")
                continuation.yield(.success(type: current.type, url: current.url))
                continuation.finish()
                return
            }

            // 如果 Ping 失败，且需要重新解析 (fallback logic omitted/simplified for now as we don't know original server ID here)
            // If failed, throw error.
            throw SynologyError.network(message: "Connection unreachable")

        } catch {
            Logger.error("CheckDeviceConnection#checkConnectionStatus, connection check failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
        }
    }
}

// MARK: - Connection Resolution Logic

extension CheckDeviceConnection {
    /// 解析可用连接（封装 Ping 测试、QuickConnect 解析、AudioStation 验证等逻辑）
    /// Resolve available connection (encapsulates Ping test, QuickConnect resolution, AudioStation verification)
    public func resolveAvailableConnection(server: String, enableHttps: Bool, verifyAudioStation: Bool) async throws -> (type: ConnectionType, url: String) {
        let targetServer = server
        let targetEnableHttps = enableHttps

        // 1. 检查是否为 QuickConnect ID
        if !quickConnectApi.isQuickConnectId(server: targetServer) {
            // 自定义域名/IP，直接返回
            // Custom domain/IP, return directly
            // 可选：在此处做 Ping 检查以确保地址有效
            // Optional: Do ping check here to ensure address is valid
            return (.custom_domain, targetServer)
        }

        // 2. 通过 QuickConnect 解析
        // Resolve via QuickConnect
        Logger.info("CheckDeviceConnection#resolveAvailableConnection, resolving via QuickConnect for \(targetServer)")
        do {
            let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(
                quickConnectId: targetServer,
                enableHttps: targetEnableHttps,
                save: false // 不再通过 QC API 自动保存，由业务层管理状态
            )

            // 可选：验证 AudioStation (verify AudioStation)
            if verifyAudioStation {
                _ = try? await audioStationApi.info.query()
            }

            return (connection.type, connection.url)
        } catch {
            Logger.error("CheckDeviceConnection#resolveAvailableConnection, QuickConnect failed: \(error)")
            throw error
        }
    }
}
