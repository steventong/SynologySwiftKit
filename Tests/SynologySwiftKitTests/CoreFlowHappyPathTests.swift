import XCTest
@testable import SynologySwiftKit

final class CoreFlowHappyPathTests: XCTestCase {
    func testCheckConnectionStatusReturnsCachedCurrentConnection() async {
        let apiClient = MockApiClient()
        apiClient.connection = (.custom_domain, "https://nas.local")

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.local", username: "tester", password: "secret", isEnableHttps: true)

        let checker = CheckDeviceConnection(
            apiClient: apiClient,
            apiInfoApi: TestApiInfoProvider(),
            quickConnectApi: QuickConnectApi(apiClient: apiClient, pingpong: TestPingPong()),
            audioStationApi: AudioStationApi(apiClient: apiClient),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )

        var events: [CheckDeviceConnectionProgress] = []
        for await progress in checker.checkConnectionStatus() {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 2)
        guard case .checking = events[0] else {
            return XCTFail("Expected checking event first")
        }
        guard case let .success(type, url, cached) = events[1] else {
            return XCTFail("Expected cached success event")
        }
        XCTAssertEqual(type, .custom_domain)
        XCTAssertEqual(url, "https://nas.local")
        XCTAssertTrue(cached)
    }

    func testPasswordLoginCompletesAndPersistsCredentialsAndSession() async {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.AUTH.name, endpoint.method == "login" {
                return AuthResult(did: "device-1", isPortalPort: false, sid: "sid-123", synotoken: nil)
            }
            throw SynologyError.network(message: "Unexpected endpoint \(endpoint.apiName)#\(endpoint.method)")
        }

        let keychain = KeyChainStorage(service: UUID().uuidString)
        let login = SynologyUserLogin(
            apiInfoApi: TestApiInfoProvider(),
            apiClient: apiClient,
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )

        var events: [SynologyUserLoginProgress] = []
        for await progress in await login.login(
            server: "nas.local",
            enableHttps: true,
            username: "tester",
            password: "secret",
            shouldSavePassword: true
        ) {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 3)
        guard case .connecting = events[0] else {
            return XCTFail("Expected connecting event")
        }
        guard case .authenticating = events[1] else {
            return XCTFail("Expected authenticating event")
        }
        guard case let .completed(result) = events[2] else {
            return XCTFail("Expected completed login event")
        }
        XCTAssertEqual(result.sid, "sid-123")
        XCTAssertEqual(apiClient.session?.sid, "sid-123")
        XCTAssertEqual(keychain.getCredentials()?.username, "tester")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "sid-123")
    }

    func testQueryAllSongsStreamsAllBatches() async {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            guard endpoint.apiName == SynologyApi.AudioStation.SONG.name, endpoint.method == "list" else {
                throw SynologyError.network(message: "Unexpected endpoint")
            }

            let limit = endpoint.parameters["limit"]?.stringValue
            let offset = endpoint.parameters["offset"]?.stringValue

            switch (limit, offset) {
            case ("1", "0"):
                return SongListResult(offset: 0, total: 3, songs: [makeSong(id: "music_1")])
            case ("2", "0"):
                return SongListResult(offset: 0, total: 3, songs: [makeSong(id: "music_1"), makeSong(id: "music_2")])
            case ("2", "2"):
                return SongListResult(offset: 2, total: 3, songs: [makeSong(id: "music_3")])
            default:
                throw SynologyError.network(message: "Unexpected pagination \(offset ?? "nil")")
            }
        }

        let query = QueryAllSongs(apiClient: apiClient)
        var events: [QueryAllSongsProgress] = []
        for await progress in query.queryAllSongs(batchSize: 2, concurrency: 1) {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 4)
        guard case let .started(total, taskCount) = events[0] else {
            return XCTFail("Expected started event")
        }
        XCTAssertEqual(total, 3)
        XCTAssertEqual(taskCount, 2)
        guard case let .batchCompleted(songs, _, _, _) = events[1] else {
            return XCTFail("Expected first batch completion")
        }
        XCTAssertEqual(songs.count, 2)
        guard case let .completed(totalSongs) = events[3] else {
            return XCTFail("Expected completed event")
        }
        XCTAssertEqual(totalSongs, 3)
    }

    func testSynologyClientRestoresAndClearsPersistedSession() {
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveSessionInfo(sid: "persisted-sid", did: "persisted-did")

        let client = SynologyClient(
            config: .default,
            keyValueStorage: MockKeyValueStorage(),
            keyChainStorage: keychain,
            apiClient: ApiClient(httpTransport: MockHTTPTransport())
        )

        XCTAssertTrue(client.hasValidSession())
        XCTAssertEqual(client.getSession()?.sid, "persisted-sid")

        client.clearSession()

        XCTAssertFalse(client.hasValidSession())
        XCTAssertNil(keychain.getSessionInfo())
    }
}
