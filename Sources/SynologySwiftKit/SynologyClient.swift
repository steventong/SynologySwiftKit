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
    private let keychainStorage: KeychainStorage
    private let storage: KeyValueStorage

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

    // MARK: - Business Flows (Lazy initialized for performance if needed, but currently pre-warmed)

    /// 用户登录流程
    public let userLogin: SynologyUserLogin

    /// 设备连接检查
    public let checkConnection: CheckDeviceConnection

    /// 查询所有歌曲
    public let queryAllSongs: QueryAllSongs

    /// PingPong
    public let pingpong: PingPong

    /// 当前连接信息（如果已建立连接）
    /// Current connection info if available
    public var currentConnection: (type: ConnectionType, url: String)? {
        apiClient.currentConnection
    }

    /// 读取已保存的登录凭据
    /// Read saved login credentials
    public func getCredentials() -> (server: String, username: String, password: String, isEnableHttps: Bool?)? {
        keychainStorage.getCredentials()
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

        // Backward compatibility: migrate legacy Keychain session to UserDefaults.
        if let session = keychainStorage.getSessionInfo(), !session.sid.isEmpty {
            updateSession(sid: session.sid, did: session.did)
            keychainStorage.removeSessionInfo()
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
        keychainStorage.removeSessionInfo()
    }

    // MARK: - Initialization

    /// 初始化 Synology 客户端
    /// - Parameter config: 全局配置 (默认为 SynologyConfig.default)
    public init(config: SynologyConfig = .default) {
        self.config = config

        let storage = UserDefaultsStorage()
        let keychainStorage = KeychainStorage()
        self.storage = storage
        self.keychainStorage = keychainStorage

        // let connection = DeviceConnection(storage: storage, keychainStorage: keychainStorage)
        // DeviceConnection removed.

        let client = ApiClient()
        let info = ApiInfoApi(apiClient: client, cacheValidity: config.apiInfoCacheValidity)
        let pingpong = PingPong(apiClient: client, timeout: config.pingpongTimeout)

        // deviceConnection = connection -> Removed
        apiClient = client
        apiInfo = info
        self.pingpong = pingpong

        // 注入 API 信息提供者
        client.apiInfoProvider = info

        // 初始化各个 API 模块
        audioStation = AudioStationApi(apiClient: client, storage: storage)
        fileStation = FileStationApi(apiClient: client)

        // Inject device identity via KeychainStorage
        auth = AuthApi(apiClient: client, keychainStorage: keychainStorage)

        quickConnect = QuickConnectApi(apiClient: client,
                                       pingpong: pingpong,
                                       timeout: config.quickConnectTimeout,
                                       storage: storage)
        dsmInfo = DsmInfoApi(apiClient: client)
        encryption = EncryptionApi(apiClient: client)

        // 初始化流程类
        userLogin = SynologyUserLogin(keychainStorage: keychainStorage,
                                      apiInfoApi: info,
                                      apiClient: client,
                                      pingpong: pingpong)
        checkConnection = CheckDeviceConnection(apiClient: client, apiInfoApi: info, quickConnectApi: quickConnect, pingpong: pingpong, audioStationApi: audioStation)
        queryAllSongs = QueryAllSongs(apiClient: client)

        // 恢复上次会话（在 getSession 内自动恢复/迁移）
        // Restore previous session (auto restore/migrate in getSession).
        _ = getSession()
    }
}
