//
//  SynologyClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import SwiftHttpClient

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

    private let keyChainStorage: any SensitiveStorage

    /// Register a public request interceptor.
    public func addInterceptor(_ interceptor: any SynologyRequestInterceptor) {
        apiClient.addInterceptor(PublicRequestInterceptorAdapter(interceptor))
    }

    // MARK: - Initialization

    /// 初始化 Synology 客户端
    /// - Parameters:
    ///   - config: 全局配置 (默认为 SynologyConfig.default)
    ///   - keyValueStorage: 非敏感缓存存储，默认使用统一 `StorageService`
    ///   - keyChainStorage: 敏感信息存储，默认使用统一 `StorageService`
    ///   - httpClientFactory: HTTP 客户端工厂，默认按请求创建 `SwiftHttpClient.HTTPClient`
    ///   - autoRegisterAuthInterceptor: 是否自动注册默认鉴权拦截器
    ///   - interceptors: 初始化时需要预注册的额外拦截器
    public convenience init(config: SynologyConfig = .default,
                            keyValueStorage: KeyValueStorage = StorageService(),
                            keyChainStorage: any SensitiveStorage = StorageService(),
                            httpClientFactory: @escaping SynologyHTTPClientFactory = defaultSynologyHTTPClientFactory,
                            autoRegisterAuthInterceptor: Bool = true) {
        self.init(
            config: config,
            keyValueStorage: keyValueStorage,
            keyChainStorage: keyChainStorage,
            apiClient: ApiClient(httpClientFactory: httpClientFactory),
            autoRegisterAuthInterceptor: autoRegisterAuthInterceptor
        )
    }

    init(
        config: SynologyConfig,
        keyValueStorage: KeyValueStorage,
        keyChainStorage: any SensitiveStorage,
        apiClient: ApiClient,
        autoRegisterAuthInterceptor: Bool = true,
        interceptors: [RequestInterceptor] = []
    ) {
        let container = SynologyClientContainer(
            config: config,
            keyValueStorage: keyValueStorage,
            keyChainStorage: keyChainStorage,
            apiClient: apiClient,
            autoRegisterAuthInterceptor: autoRegisterAuthInterceptor,
            interceptors: interceptors
        )
        self.config = config
        self.keyChainStorage = keyChainStorage
        self.apiClient = container.apiClient
        self.auth = container.auth
        self.system = container.system
        self.audioStation = container.audioStation
        self.files = container.files
        self.session = container.session
        self.flows = container.flows
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

    // MARK: - Direct API Entry Points

    public var quickConnect: QuickConnectClient { system.connection.quickConnect }
    public var dsmInfo: DSMInfoClient { system.dsmInfo }
    public var encryption: EncryptionClient { system.encryption }

    public var pins: PinApi { audioStation.pins }
    public var folders: FolderApi { audioStation.folders }
    public var albums: AlbumApi { audioStation.albums }
    public var artists: ArtistApi { audioStation.artists }
    public var composers: ComposerApi { audioStation.composers }
    public var genres: GenreApi { audioStation.genres }
    public var songs: SongApi { audioStation.songs }
    public var playlists: PlaylistApi { audioStation.playlists }
    public var lyrics: LyricsApi { audioStation.lyrics }
    public var search: SearchApi { audioStation.search }
    public var covers: CoverApi { audioStation.covers }
    public var stream: StreamApi { audioStation.stream }
    public var tagEditor: TagEditorApi { audioStation.tagEditor }
}

private struct SynologyClientContainer {
    let apiClient: ApiClient
    let auth: AuthClient
    let system: SystemClient
    let audioStation: AudioStationClient
    let files: FileStationClient
    let session: SessionClient
    let flows: FlowClient

    init(
        config: SynologyConfig,
        keyValueStorage: KeyValueStorage,
        keyChainStorage: any SensitiveStorage,
        apiClient: ApiClient,
        autoRegisterAuthInterceptor: Bool,
        interceptors: [RequestInterceptor]
    ) {
        self.apiClient = apiClient
        Logger.isEnabled = config.enableNetworkLogging
        Self.restorePersistedConnectionAndSessionIfNeeded(
            apiClient: apiClient,
            keyChainStorage: keyChainStorage
        )

        let apiInfo = ApiInfoApi(apiClient: apiClient, cacheValidity: config.apiInfoCacheValidity)
        let ping = PingPong(apiClient: apiClient, timeout: config.pingpongTimeout)
        apiClient.apiInfoProvider = apiInfo

        let audioStationClient = AudioStationClient(apiClient: apiClient, keyValueStorage: keyValueStorage)
        self.audioStation = audioStationClient
        self.files = FileStationClient(apiClient: apiClient)
        let authClient = AuthClient(apiClient: apiClient, keyChainStorage: keyChainStorage)
        self.auth = authClient

        let quickConnect = QuickConnectClient(
            apiClient: apiClient,
            pingpong: ping,
            timeout: config.quickConnectTimeout,
            keyValueStorage: keyValueStorage
        )
        let dsmInfo = DSMInfoClient(apiClient: apiClient)
        let encryption = EncryptionClient(apiClient: apiClient)
        self.system = SystemClient(
            dsmInfo: dsmInfo,
            encryption: encryption,
            connection: ConnectionClient(quickConnect: quickConnect, ping: ping)
        )

        let checkConnection = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: quickConnect,
            pingpong: ping,
            keyChainStorage: keyChainStorage
        )
        let connectionManager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: quickConnect,
            pingpong: ping,
            audioStationApi: audioStationClient,
            apiInfoApi: apiInfo,
            authApi: authClient,
            keyChainStorage: keyChainStorage
        )
        let userLogin = SynologyUserLogin(
            apiInfoApi: apiInfo,
            apiClient: apiClient,
            authApi: authClient,
            audioStationApi: audioStationClient,
            connectionChecker: checkConnection,
            keyChainStorage: keyChainStorage
        )
        let queryAllSongs = QueryAllSongs(apiClient: apiClient)
        let userLoginFlow = UserLoginFlowClient(loginFlow: userLogin)
        let connectionCheckFlow = ConnectionCheckFlowClient(connectionCheck: checkConnection)
        let connectionFlow = ConnectionManagerFlowClient(connectionManager: connectionManager)
        let queryAllSongsFlow = QueryAllSongsFlowClient(queryFlow: queryAllSongs)
        self.flows = FlowClient(
            userLogin: userLoginFlow,
            connectionCheck: connectionCheckFlow,
            connection: connectionFlow,
            queryAllSongs: queryAllSongsFlow
        )
        self.session = SessionClient(
            connectionProvider: { [weak apiClient, weak keyChainStorage] in
                if let connection = apiClient?.connection {
                    return SynologyConnection(type: connection.type, url: connection.url)
                }

                if let persisted = keyChainStorage?.getConnectionInfo(),
                   let type = ConnectionType(rawValue: persisted.typeString)
                {
                    apiClient?.updateConnection(type: type, url: persisted.url)
                    return SynologyConnection(type: type, url: persisted.url)
                }

                return nil
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
            connectionUpdater: { [weak apiClient, weak keyChainStorage] type, url in
                apiClient?.updateConnection(type: type, url: url)
                keyChainStorage?.saveConnectionInfo(url: url, typeString: type.rawValue)
            },
            sessionUpdater: { [weak apiClient] sid, did in
                apiClient?.updateSession(sid: sid, did: did)
            },
            sessionClearer: { [weak apiClient, weak keyChainStorage] in
                apiClient?.clearSession()
                keyChainStorage?.removeSessionInfo()
            }
        )

        // Warm up persisted connection/session eagerly so first API call does not
        // race with lazy restoration from host-side storage.
        _ = session.connection
        _ = session.current

        if autoRegisterAuthInterceptor {
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

    private static func restorePersistedConnectionAndSessionIfNeeded(
        apiClient: ApiClient,
        keyChainStorage: any SensitiveStorage
    ) {
        if let persistedConnection = keyChainStorage.getConnectionInfo(),
           let connectionType = ConnectionType(rawValue: persistedConnection.typeString)
        {
            apiClient.updateConnection(type: connectionType, url: persistedConnection.url)
        }

        if let persistedSession = keyChainStorage.getSessionInfo(),
           !persistedSession.sid.isEmpty
        {
            apiClient.updateSession(sid: persistedSession.sid, did: persistedSession.did)
        }
    }
}
