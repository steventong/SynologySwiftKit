//
//  SynologyClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - SynologyClient

/// Synology 服务容器（依赖注入中心）
/// Synology service container (dependency injection center)
///
/// 统一的服务入口，管理所有依赖和 API 模块。
/// Unified service entry point, managing all dependencies and API modules.
public final class SynologyClient {
    // MARK: - Core Services

    /// API 客户端
    let apiClient: ApiClient

    /// 全局配置
    public let config: SynologyConfig

    /// API 信息管理
    public let apiInfo: ApiInfoApi

    // MARK: - API Modules

    /// AudioStation API
    public let audioStation: AudioStationApi

    /// FileStation API
    public let fileStation: FileStationApi

    /// 认证 API
    public let auth: AuthApi

    /// QuickConnect API
    public let quickConnect: QuickConnectApi

    /// DSM 信息 API
    public let dsmInfo: DsmInfoApi

    /// 加密 API
    public let encryption: EncryptionApi

    /// PingPong
    public let pingpong: PingPong

    // MARK: - Business Flows (Lazy initialized for performance if needed, but currently pre-warmed)

    /// 用户登录流程
    public let userLogin: SynologyUserLogin

    /// 设备连接检查
    public let checkConnection: CheckDeviceConnection

    /// 查询所有歌曲
    public let queryAllSongs: QueryAllSongs

    private let keyChainStorage: KeyChainStorage
    private let keyValueStorage: KeyValueStorage

    /// 注册请求拦截器
    /// Register request interceptor
    public func addInterceptor(_ interceptor: RequestInterceptor) {
        apiClient.addInterceptor(interceptor)
    }

    // MARK: - Initialization

    /// 初始化 Synology 客户端
    /// - Parameter config: 全局配置 (默认为 SynologyConfig.default)
    public init(config: SynologyConfig = .default) {
        self.config = config

        keyValueStorage = UserDefaultsStorage()
        keyChainStorage = KeyChainStorage()

        apiClient = ApiClient()
        apiInfo = ApiInfoApi(apiClient: apiClient, cacheValidity: config.apiInfoCacheValidity)
        pingpong = PingPong(apiClient: apiClient, timeout: config.pingpongTimeout)

        // 注入 API 信息提供者
        apiClient.apiInfoProvider = apiInfo

        // 初始化各个 API 模块
        audioStation = AudioStationApi(apiClient: apiClient, keyValueStorage: keyValueStorage)
        fileStation = FileStationApi(apiClient: apiClient)

        // Inject device identity via KeychainStorage
        auth = AuthApi(apiClient: apiClient, keyChainStorage: keyChainStorage)

        quickConnect = QuickConnectApi(apiClient: apiClient, pingpong: pingpong, timeout: config.quickConnectTimeout, storage: keyValueStorage)
        dsmInfo = DsmInfoApi(apiClient: apiClient)
        encryption = EncryptionApi(apiClient: apiClient)

        // 初始化流程类
        userLogin = SynologyUserLogin(keyChainStorage: keyChainStorage, apiInfoApi: apiInfo, apiClient: apiClient, pingpong: pingpong)
        checkConnection = CheckDeviceConnection(apiClient: apiClient, apiInfoApi: apiInfo, quickConnectApi: quickConnect, pingpong: pingpong, audioStationApi: audioStation)
        queryAllSongs = QueryAllSongs(apiClient: apiClient)

        // 恢复上次会话
        // Restore previous session
        _ = getSession()

        // 默认注册鉴权拦截器（按需补充 sid/cookie，并在会话失效时清理持久化会话）
        apiClient.addInterceptor(AuthInterceptor(
            sessionProvider: { [weak apiClient] in
                apiClient?.session
            },
            onSessionExpired: { [weak apiClient, weak keyChainStorage] in
                apiClient?.clearSession()
                keyChainStorage?.removeSessionInfo()
            }
        ))
    }
}

extension SynologyClient {
    /// 当前连接信息（如果已建立连接）
    /// Current connection info if available
    public func getConnection() -> (type: ConnectionType, url: String)? {
        return apiClient.connection
    }

    /// 读取已保存的登录凭据
    /// Read saved login credentials
    public func getCredentials() -> (server: String, username: String, password: String, isEnableHttps: Bool?)? {
        keyChainStorage.getCredentials()
    }

    /// 更新 Session（内存 + 本地持久化）
    /// Update session (memory + local persistence)
    public func updateSession(sid: String, did: String?) {
        apiClient.updateSession(sid: sid, did: did)
    }

    /// 获取 Session（优先内存，其次本地持久化）
    /// Get session (memory first, then local persistence)
    public func getSession() -> (sid: String, did: String?)? {
        if let current = apiClient.session, !current.sid.isEmpty {
            return current
        }

        if let session = keyChainStorage.getSessionInfo(), !session.sid.isEmpty {
            updateSession(sid: session.sid, did: session.did)
            return (session.sid, session.did)
        }

        return nil
    }

    /// 检查是否存在有效 Session（不暴露 sid/did）
    /// Check whether a valid session exists (without exposing sid/did)
    public func hasValidSession() -> Bool {
        getSession() != nil
    }

    /// 移除当前 Session（内存 + 本地持久化）
    /// Remove current session (memory + local persistence)
    public func clearSession() {
        apiClient.clearSession()
        keyChainStorage.removeSessionInfo()
    }
}
