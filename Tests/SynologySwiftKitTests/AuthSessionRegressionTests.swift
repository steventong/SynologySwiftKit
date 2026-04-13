import XCTest
@testable import SynologySwiftKit

final class AuthSessionRegressionTests: XCTestCase {
    func testCheckConnectionStatusWithoutCredentialsEmitsFailure() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        let checker = CheckDeviceConnection(
            apiClient: apiClient,
            apiInfoApi: MockApiInfoProvider(),
            quickConnectApi: QuickConnectApi(apiClient: apiClient, pingpong: MockPingPong()),
            audioStationApi: AudioStationApi(apiClient: apiClient),
            pingpong: MockPingPong(),
            keyChainStorage: keychain
        )

        var events: [CheckDeviceConnectionProgress] = []
        for await progress in checker.checkConnectionStatus() {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 1)
        guard case let .failed(message) = events[0] else {
            return XCTFail("Expected a terminal failure event")
        }
        XCTAssertTrue(message.contains("no saved credentials"))
    }

    func testSilentLoginWithExpiredCachedSessionReturnsInvalidSession() async {
        let apiClient = MockApiClient()
        apiClient.connection = (.custom_domain, "https://nas.local")
        apiClient.session = ("expired-sid", nil)
        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.AudioStation.INFO.name {
                throw SynologyError.sessionExpired(code: 105, message: "expired")
            }
            throw SynologyError.network(message: "Unexpected endpoint: \(endpoint.apiName)")
        }

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.local", username: "tester", password: "secret", isEnableHttps: true)
        keychain.saveSessionInfo(sid: "expired-sid", did: nil)

        let login = SynologyUserLogin(
            apiInfoApi: MockApiInfoProvider(),
            apiClient: apiClient,
            pingpong: MockPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )

        var events: [SynologyUserLoginProgress] = []
        for await progress in await login.login() {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 3)
        guard case .connecting = events[0] else {
            return XCTFail("Expected connecting progress first")
        }
        guard case .authenticating = events[1] else {
            return XCTFail("Expected authenticating progress second")
        }
        guard case let .invalidSession(message) = events[2] else {
            return XCTFail("Expected invalidSession instead of completed")
        }
        XCTAssertEqual(message, "session expired")
    }

    func testLogoutClearsLocalSessionState() async throws {
        let apiClient = MockApiClient()
        apiClient.session = ("sid-123", "did-123")
        apiClient.mockResponse = EmptyData()

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveSessionInfo(sid: "sid-123", did: "did-123")

        let authApi = AuthApi(apiClient: apiClient, keyChainStorage: keychain)
        try await authApi.logout()

        XCTAssertNil(apiClient.session)
        XCTAssertNil(keychain.getSessionInfo())
    }
}

private struct MockApiInfoProvider: ApiInfoProviding {
    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
        ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil)
    }

    func checkSynologyApiInfo(cacheEnabled: Bool?, updateCache: Bool?) async throws -> Bool {
        true
    }
}

private struct MockPingPong: PingPongProviding {
    let singleURLReachable: Bool

    init(singleURLReachable: Bool = false) {
        self.singleURLReachable = singleURLReachable
    }

    func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String] {
        [:]
    }

    func pingpongFirst(connections: [ConnectionType: [String]]) async -> (type: ConnectionType, url: String)? {
        nil
    }

    func pingpong(url: String) async -> Bool {
        singleURLReachable
    }
}
