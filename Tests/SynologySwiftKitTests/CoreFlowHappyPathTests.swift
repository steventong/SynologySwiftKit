import XCTest
@testable import SynologySwiftKit

final class CoreFlowHappyPathTests: XCTestCase {
    func testPasswordLoginCompletesAndPersistsCredentialsAndSession() async {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.AUTH.name, endpoint.method == "login" {
                return AuthResult(did: "device-1", isPortalPort: false, sid: "sid-123", synotoken: nil)
            }
            throw SynologyError.network(message: "Unexpected endpoint \(endpoint.apiName)#\(endpoint.method)")
        }

        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        let authApi = AuthClient(apiClient: apiClient, keyChainStorage: keychain)
        let audioStationApi = AudioStationClient(apiClient: apiClient)
        let connectionChecker = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong(singleURLReachable: true)),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )
        let login = SynologyUserLogin(
            apiInfoApi: TestApiInfoProvider(),
            apiClient: apiClient,
            authApi: authApi,
            audioStationApi: audioStationApi,
            connectionChecker: connectionChecker,
            keyChainStorage: keychain
        )

        var events: [SynologyUserLoginProgress] = []
        for await progress in login.login(
            server: "https://nas.local",
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
        XCTAssertEqual(result.session.sid, "sid-123")
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
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveSessionInfo(sid: "persisted-sid", did: "persisted-did")

        let client = SynologyClient(
            config: .default,
            keyValueStorage: MockKeyValueStorage(),
            keyChainStorage: keychain,
            apiClient: ApiClient(httpClientFactory: HTTPClientFactorySpy().makeFactory())
        )

        XCTAssertTrue(client.session.hasValidSession)
        XCTAssertEqual(client.session.current?.sid, "persisted-sid")

        client.session.clear()

        XCTAssertFalse(client.session.hasValidSession)
        XCTAssertNil(keychain.getSessionInfo())
    }

    func testSynologyClientSupportsManualConnectionAndSessionConfiguration() {
        let client = SynologyClient(
            config: .default,
            keyValueStorage: MockKeyValueStorage(),
            keyChainStorage: makeKeyChainStorage(service: UUID().uuidString),
            apiClient: ApiClient(httpClientFactory: HTTPClientFactorySpy().makeFactory())
        )

        client.configureConnection(type: .custom_domain, url: "https://nas.local", sid: "sid-123", did: "did-123")

        XCTAssertEqual(client.session.connection?.type, .custom_domain)
        XCTAssertEqual(client.session.connection?.url, "https://nas.local")
        XCTAssertEqual(client.session.current?.sid, "sid-123")
        XCTAssertEqual(client.session.current?.did, "did-123")
        XCTAssertTrue(client.quickConnect === client.system.connection.quickConnect)
        XCTAssertTrue(client.songs === client.audioStation.songs)
        XCTAssertTrue(client.stream === client.audioStation.stream)
        XCTAssertTrue(client.lyrics === client.audioStation.lyrics)
        XCTAssertTrue(client.dsmInfo === client.system.dsmInfo)
        XCTAssertTrue(client.encryption === client.system.encryption)
    }

    func testSynologyClientFactorySupportsExistingSession() {
        let client = SynologyClientFactory.makeWithExistingSession(
            connectionType: .custom_domain,
            url: "https://nas.local",
            sid: "sid-123",
            did: "did-123",
            keyValueStorage: MockKeyValueStorage(),
            keyChainStorage: makeKeyChainStorage(service: UUID().uuidString),
            httpClientFactory: HTTPClientFactorySpy().makeFactory()
        )

        XCTAssertEqual(client.session.connection?.url, "https://nas.local")
        XCTAssertEqual(client.session.current?.sid, "sid-123")
        XCTAssertEqual(client.session.current?.did, "did-123")
    }

    func testSessionStateSupportsConcurrentUpdatesAndReads() async {
        let client = SynologyClient(
            config: .default,
            keyValueStorage: MockKeyValueStorage(),
            keyChainStorage: makeKeyChainStorage(service: UUID().uuidString),
            apiClient: ApiClient(httpClientFactory: HTTPClientFactorySpy().makeFactory())
        )

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 20 {
                group.addTask {
                    client.configureConnection(type: .custom_domain, url: "https://nas-\(index).local")
                    client.configureSession(sid: "sid-\(index)", did: "did-\(index)")
                    _ = client.session.current
                    _ = client.session.connection
                }
            }
        }

        XCTAssertNotNil(client.session.current?.sid)
        XCTAssertNotNil(client.session.connection?.url)
    }
}
