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
            apiClient: ApiClient(
                httpClientFactory: httpClientFactory,
                keyValueStorage: keyValueStorage
            ),
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
        apiClient.sessionOperations.replaceState {
            apiClient.apiInfoProvider?.selectServer(url)
            apiClient.updateConnection(type: type, url: url)
            keyChainStorage.saveConnectionInfo(url: url, typeString: type.rawValue)
            apiClient.updateSession(sid: sid, did: did)
        }
    }

    /// 允许当前服务器证书，并在后续请求中校验同一 SHA-256 指纹。
    /// Approve the current server certificate and require the same SHA-256 fingerprint later.
    public func approveServerCertificate(_ certificate: SynologyServerCertificate) {
        apiClient.approveServerCertificate(certificate)
    }

    /// 返回某个 host 已获用户批准的证书指纹，供宿主的媒体请求复用。
    /// Return the approved certificate fingerprint for host-app media requests.
    public func approvedServerCertificateFingerprint(forHost host: String) -> String? {
        apiClient.approvedServerCertificateFingerprint(forHost: host)
    }

    /// 将当前 DSM 会话生成的媒体资源下载到临时文件。
    /// Download a media resource from the current DSM session to a temporary file.
    public func downloadMediaFile(from url: URL) async throws -> URL {
        try await apiClient.downloadMediaFile(url: url)
    }

    /// Fetch a small media resource using the current DSM certificate policy.
    public func fetchMediaData(from url: URL) async throws -> Data {
        try await apiClient.fetchMediaData(url: url)
    }

    /// Create an ordered streaming or durable background media transport with the same certificate policy as login.
    public func makeMediaTransferSession(configuration: SynologyMediaTransferConfiguration, delegateQueue: OperationQueue,
                                         delegate: any SynologyMediaTransferSessionDelegate) -> SynologyMediaTransferSession {
        apiClient.makeMediaTransferSession(configuration: configuration, delegateQueue: delegateQueue, delegate: delegate)
    }

    // MARK: - Direct API Entry Points

    public var quickConnect: QuickConnectClient { system.connection.quickConnect }
    public var dsmInfo: DSMInfoClient { system.dsmInfo }
    public var encryption: EncryptionClient { system.encryption }


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
        Logger.destination = config.logDestination
        Logger.handler = config.logHandler
        Self.restorePersistedConnectionAndSessionIfNeeded(
            apiClient: apiClient,
            keyChainStorage: keyChainStorage
        )

        apiClient.publishCommittedState()

        let apiInfo = ApiInfoApi(apiClient: apiClient, keyValueStorage: keyValueStorage)
        let ping = PingPong(apiClient: apiClient, timeout: config.pingpongTimeout)
        apiInfo.selectServer(keyChainStorage.getCredentials()?.server)
        apiClient.apiInfoProvider = apiInfo

        let audioStationClient = AudioStationClient(apiClient: apiClient, keyValueStorage: keyValueStorage)
        self.audioStation = audioStationClient
        self.files = FileStationClient(apiClient: apiClient)
        let sessionOperations = apiClient.sessionOperations
        let authClient = AuthClient(apiClient: apiClient, keyChainStorage: keyChainStorage, sessionOperations: sessionOperations)
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
            connection: ConnectionClient(quickConnect: quickConnect, ping: ping),
            desktopTimeout: DesktopTimeoutClient(apiClient: apiClient),
            normalUser: NormalUserClient(apiClient: apiClient)
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
            dsmInfoApi: dsmInfo,
            sessionValidationTimeout: config.pingpongTimeout,
            apiInfoApi: apiInfo,
            keyChainStorage: keyChainStorage,
            sessionOperations: sessionOperations
        )
        let userLogin = SynologyUserLogin(
            apiInfoApi: apiInfo,
            apiClient: apiClient,
            authApi: authClient,
            dsmInfoApi: dsmInfo,
            sessionValidationTimeout: config.pingpongTimeout,
            connectionChecker: checkConnection,
            keyChainStorage: keyChainStorage,
            sessionOperations: sessionOperations
        )
        let userLoginFlow = UserLoginFlowClient(loginFlow: userLogin)
        let connectionCheckFlow = ConnectionCheckFlowClient(connectionCheck: checkConnection)
        let connectionFlow = ConnectionManagerFlowClient(connectionManager: connectionManager)
        self.flows = FlowClient(
            userLogin: userLoginFlow,
            connectionCheck: connectionCheckFlow,
            connection: connectionFlow
        )
        self.session = SessionClient(
            connectionProvider: { [weak apiClient] in
                apiClient?.committedConnection.map { SynologyConnection(type: $0.type, url: $0.url) }
            },
            sessionProvider: { [weak apiClient] in
                guard let current = apiClient?.committedSession, !current.sid.isEmpty else { return nil }
                return SynologySession(sid: current.sid, did: current.did)
            },
            connectionUpdater: { [weak apiClient, weak keyChainStorage] type, url in
                sessionOperations.replaceState {
                    apiClient?.apiInfoProvider?.selectServer(url)
                    apiClient?.updateConnection(type: type, url: url)
                    keyChainStorage?.saveConnectionInfo(url: url, typeString: type.rawValue)
                }
            },
            sessionUpdater: { [weak apiClient] sid, did in
                sessionOperations.replaceState { apiClient?.updateSession(sid: sid, did: did) }
            },
            sessionClearer: { [weak apiClient, weak keyChainStorage] in
                sessionOperations.replaceState {
                    apiClient?.clearSession()
                    keyChainStorage?.removeSessionInfo()
                }
            }
        )

        if autoRegisterAuthInterceptor {
            apiClient.addInterceptor(AuthInterceptor(
                sessionProvider: { [weak apiClient] in
                    apiClient?.session
                },
                onSessionExpired: { [weak apiClient, weak keyChainStorage] in
                    sessionOperations.mutateForCurrentRequest {
                        apiClient?.clearSession()
                        keyChainStorage?.removeSessionInfo()
                    }
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
