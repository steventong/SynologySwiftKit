import Foundation

public enum SynologyClientFactory {
    public static func make(
        config: SynologyConfig = .default,
        keyValueStorage: KeyValueStorage = UserDefaultsStorage(),
        keyChainStorage: KeyChainStorage = KeyChainStorage(),
        httpClient: HTTPClientProtocol = URLSessionHTTPClient(),
        autoRegisterAuthInterceptor: Bool = true
    ) -> SynologyClient {
        SynologyClient(
            config: config,
            keyValueStorage: keyValueStorage,
            keyChainStorage: keyChainStorage,
            httpClient: httpClient,
            autoRegisterAuthInterceptor: autoRegisterAuthInterceptor
        )
    }

    public static func makeWithExistingSession(
        connectionType: ConnectionType,
        url: String,
        sid: String,
        did: String? = nil,
        config: SynologyConfig = .default,
        keyValueStorage: KeyValueStorage = UserDefaultsStorage(),
        keyChainStorage: KeyChainStorage = KeyChainStorage(),
        httpClient: HTTPClientProtocol = URLSessionHTTPClient()
    ) -> SynologyClient {
        let client = make(
            config: config,
            keyValueStorage: keyValueStorage,
            keyChainStorage: keyChainStorage,
            httpClient: httpClient
        )
        client.configureConnection(type: connectionType, url: url, sid: sid, did: did)
        return client
    }
}
