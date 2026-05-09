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

    // MARK: - API Modules

    public let auth: AuthClient
    public let system: SystemClient
    public let audioStation: AudioStationClient
    public let files: FileStationClient
    public let session: SessionClient
    public let flows: FlowClient

    private let keyChainStorage: KeyChainStorage

    /// Register a public request interceptor.
    public func addInterceptor(_ interceptor: any SynologyRequestInterceptor) {
        apiClient.addInterceptor(PublicRequestInterceptorAdapter(interceptor))
    }

    // MARK: - Initialization

    /// 初始化 Synology 客户端
    /// - Parameters:
    ///   - config: 全局配置 (默认为 SynologyConfig.default)
    ///   - keyValueStorage: 非敏感缓存存储，默认使用 `UserDefaultsStorage`
    ///   - keyChainStorage: 敏感信息存储，默认使用 `KeyChainStorage`
    ///   - httpClient: HTTP 客户端实现，默认使用 `URLSessionHTTPClient`
    ///   - autoRegisterAuthInterceptor: 是否自动注册默认鉴权拦截器
    ///   - interceptors: 初始化时需要预注册的额外拦截器
    public convenience init(config: SynologyConfig = .default,
                            keyValueStorage: KeyValueStorage = UserDefaultsStorage(),
                            keyChainStorage: KeyChainStorage = KeyChainStorage(),
                            httpClient: HTTPClientProtocol = URLSessionHTTPClient(),
                            autoRegisterAuthInterceptor: Bool = true) {
        self.init(
            config: config,
            keyValueStorage: keyValueStorage,
            keyChainStorage: keyChainStorage,
            apiClient: ApiClient(httpClient: httpClient),
            autoRegisterAuthInterceptor: autoRegisterAuthInterceptor
        )
    }

    init(
        config: SynologyConfig,
        keyValueStorage: KeyValueStorage,
        keyChainStorage: KeyChainStorage,
        apiClient: ApiClient,
        autoRegisterAuthInterceptor: Bool = true,
        interceptors: [RequestInterceptor] = []
    ) {
        self.config = config
        self.keyChainStorage = keyChainStorage

        self.apiClient = apiClient
        Logger.isEnabled = config.enableNetworkLogging
        let apiInfo = ApiInfoApi(apiClient: apiClient, cacheValidity: config.apiInfoCacheValidity)
        let ping = PingPong(apiClient: apiClient, timeout: config.pingpongTimeout)

        // 注入 API 信息提供者
        apiClient.apiInfoProvider = apiInfo

        // 初始化各个 API 模块
        let audioStationClient = AudioStationClient(apiClient: apiClient, keyValueStorage: keyValueStorage)
        audioStation = audioStationClient
        files = FileStationClient(apiClient: apiClient)

        // Inject device identity via KeychainStorage
        auth = AuthClient(apiClient: apiClient, keyChainStorage: keyChainStorage)

        let quickConnect = QuickConnectClient(apiClient: apiClient, pingpong: ping, timeout: config.quickConnectTimeout, keyValueStorage: keyValueStorage)
        let dsmInfo = DSMInfoClient(apiClient: apiClient)
        let encryption = EncryptionClient(apiClient: apiClient)
        system = SystemClient(
            device: dsmInfo,
            security: encryption,
            network: ConnectionClient(quickConnect: quickConnect, ping: ping)
        )

        // 初始化流程类
        let checkConnection = CheckDeviceConnection(
            apiClient: apiClient,
            quickConnectApi: quickConnect,
            pingpong: ping,
            keyChainStorage: keyChainStorage
        )
        let userLogin = SynologyUserLogin(
            apiInfoApi: apiInfo,
            apiClient: apiClient,
            authApi: auth,
            audioStationApi: audioStationClient,
            connectionChecker: checkConnection,
            keyChainStorage: keyChainStorage
        )
        let queryAllSongs = QueryAllSongs(apiClient: apiClient)
        flows = FlowClient(
            auth: AuthFlowClient(loginFlow: userLogin),
            connection: ConnectionFlowClient(connectionFlow: checkConnection),
            library: LibraryFlowClient(queryFlow: queryAllSongs)
        )
        session = SessionClient(
            connectionProvider: { [weak apiClient] in
                guard let connection = apiClient?.connection else { return nil }
                return SynologyConnection(type: connection.type, url: connection.url)
            },
            sessionProvider: { [weak apiClient, weak keyChainStorage] in
                if let current = apiClient?.session, !current.sid.isEmpty {
                    return SynologySession(sid: current.sid, did: current.did)
                }

                if let persisted = keyChainStorage?.getSessionInfo(), !persisted.sid.isEmpty {
                    apiClient?.updateSession(sid: persisted.sid, did: persisted.did)
                    return SynologySession(sid: persisted.sid, did: persisted.did)
                }

                return nil
            },
            connectionUpdater: { [weak apiClient] type, url in
                apiClient?.updateConnection(type: type, url: url)
            },
            sessionUpdater: { [weak apiClient] sid, did in
                apiClient?.updateSession(sid: sid, did: did)
            },
            sessionClearer: { [weak apiClient, weak keyChainStorage] in
                apiClient?.clearSession()
                keyChainStorage?.removeSessionInfo()
            }
        )

        // 恢复上次会话
        // Restore previous session
        _ = session.current

        if autoRegisterAuthInterceptor {
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

        for interceptor in interceptors {
            apiClient.addInterceptor(interceptor)
        }
    }

    /// Configure a known DSM endpoint without running the discovery/login flows.
    public func configureConnection(type: ConnectionType, url: String) {
        session.updateConnection(type: type, url: url)
    }

    /// Configure an existing DSM session for direct SDK calls.
    public func configureSession(sid: String, did: String? = nil) {
        session.update(sid: sid, did: did)
    }

    /// Configure both endpoint and session when the host app owns persistence.
    public func configureConnection(type: ConnectionType, url: String, sid: String, did: String? = nil) {
        configureConnection(type: type, url: url)
        configureSession(sid: sid, did: did)
    }
}
