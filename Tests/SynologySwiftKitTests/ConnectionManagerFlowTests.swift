import XCTest
@testable import SynologySwiftKit

final class ConnectionManagerFlowTests: XCTestCase {
    func testRecoverConnectionRestoresPersistedQuickConnectEndpointAndSchedulesOptimization() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://cached.local", typeString: ConnectionType.lan.rawValue)
        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.AudioStation.INFO.name {
                return AudioStationInfo(
                    enable_equalizer: false,
                    playing_queue_max: 0,
                    same_subnet: false,
                    enable_user_home: false,
                    has_aac: false,
                    support_bluetooth: false,
                    version_string: nil,
                    has_music_share: false,
                    version: nil,
                    sid: "sid",
                    enable_personal_library: false,
                    settings: AudioStationInfoSettings(disable_upnp: false, enable_download: false, transcode_to_mp3: false, prefer_using_html5: false, audio_show_virtual_library: false),
                    support_usb: false,
                    dsd_decode_capability: false,
                    browse_personal_library: nil,
                    serial_number: nil,
                    privilege: AudioStationInfoPrivilege(tag_edit: false, sharing: false, upnp_browse: false, playlist_edit: false, remote_player: false),
                    support_virtual_library: false,
                    remote_controller: false,
                    transcode_capability: [],
                    is_manager: false
                )
            }
            throw SynologyError.network(message: "Unexpected endpoint: \(endpoint.apiName)")
        }

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "did", isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://cached.local")
    }

    func testRecoverConnectionWithUnreachableQuickConnectEndpointRequiresRelogin() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://cached.local", typeString: ConnectionType.lan.rawValue)
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "did", isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .requiresRelogin)
    }

    func testRecoverConnectionWithUnreachableCustomDomainDisconnects() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://nas.example.com", typeString: ConnectionType.custom_domain.rawValue)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "did", isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .disconnected)
    }

    func testRecoverConnectionWithoutCredentialsDisconnects() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "did", isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .disconnected)
    }

    func testOptimizeQuickConnectEndpointPersistsRefreshedConnection() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let refreshed = SynologyConnection(type: .lan, url: "https://192.168.1.20:5001")
        let pingpong = RecordingPingPong(firstResult: refreshed, singleURLReachable: true)
        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let connection = await manager.refreshQuickConnectEndpoint()

        XCTAssertEqual(connection?.type, .lan)
        XCTAssertEqual(connection?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(apiClient.session?.sid, "new-sid")
        XCTAssertEqual(apiClient.session?.did, "new-did")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "new-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "new-did")
        XCTAssertTrue(pingpong.singleURLPings.isEmpty)
    }

    func testRecoverConnectionKeepsReachableQuickConnectEndpointAndSkipsSynchronousOptimization() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.updateSession(sid: "old-sid", did: "old-did")
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let refreshed = SynologyConnection(type: .lan, url: "https://192.168.1.20:5001")
        let pingpong = RecordingPingPong(firstResult: refreshed, singleURLReachable: true)
        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.AudioStation.INFO.name {
                return AudioStationInfo(
                    enable_equalizer: false,
                    playing_queue_max: 0,
                    same_subnet: false,
                    enable_user_home: false,
                    has_aac: false,
                    support_bluetooth: false,
                    version_string: nil,
                    has_music_share: false,
                    version: nil,
                    sid: "old-sid",
                    enable_personal_library: false,
                    settings: AudioStationInfoSettings(disable_upnp: false, enable_download: false, transcode_to_mp3: false, prefer_using_html5: false, audio_show_virtual_library: false),
                    support_usb: false,
                    dsd_decode_capability: false,
                    browse_personal_library: nil,
                    serial_number: nil,
                    privilege: AudioStationInfoPrivilege(tag_edit: false, sharing: false, upnp_browse: false, playlist_edit: false, remote_player: false),
                    support_virtual_library: false,
                    remote_controller: false,
                    transcode_capability: [],
                    is_manager: false
                )
            }
            throw SynologyError.network(message: "Unexpected endpoint: \(endpoint.apiName)")
        }

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertEqual(pingpong.singleURLPings.first, "https://192.168.1.10:5001")
        XCTAssertFalse(pingpong.didRunBestConnectionSelection)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(apiClient.session?.did, "old-did")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
    }

    func testRecoverConnectionRequiresReloginWhenReachableEndpointHasInvalidSession() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "expired-sid", did: "old-did")
        apiClient.updateSession(sid: "expired-sid", did: "old-did")

        let pingpong = RecordingPingPong(firstResult: nil, singleURLReachable: true)
        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "did", isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.AudioStation.INFO.name {
                throw SynologyError.sessionExpired(code: 106, message: "expired")
            }
            throw SynologyError.network(message: "Unexpected endpoint: \(endpoint.apiName)")
        }

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .requiresRelogin)
        XCTAssertEqual(pingpong.singleURLPings.first, "https://192.168.1.10:5001")
    }

    func testOptimizeQuickConnectEndpointDoesNotPersistRefreshedConnectionWhenLoginFails() async throws {
        let apiClient = MockApiClient()
        apiClient.updateConnection(type: .lan, url: "https://192.168.1.10:5001")
        apiClient.updateSession(sid: "old-sid", did: "old-did")

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let refreshed = SynologyConnection(type: .lan, url: "https://192.168.1.20:5001")
        let pingpong = TestPingPong(firstResult: refreshed, singleURLReachable: true)
        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .failure(SynologyError.auth(code: 400, message: "login failed"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let connection = await manager.refreshQuickConnectEndpoint()

        XCTAssertNil(connection)
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(apiClient.session?.did, "old-did")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "old-did")
    }

    func testListReturnsCandidatesWithCurrentFlagAndReachability() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.10", port: 5001)
        }

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: nil, isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let candidates = try await manager.listCandidates()

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(candidates.first?.type, .lan)
        XCTAssertEqual(candidates.first?.isCurrent, true)
        XCTAssertEqual(candidates.first?.isReachable, true)
    }

    func testListReturnsCurrentConnectionForCustomDomain() async throws {
        let apiClient = MockApiClient()
        apiClient.updateConnection(type: .custom_domain, url: "https://nas.example.com")

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: nil, isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let candidates = try await manager.listCandidates()

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.url, "https://nas.example.com")
        XCTAssertEqual(candidates.first?.type, .custom_domain)
        XCTAssertEqual(candidates.first?.isCurrent, true)
        XCTAssertEqual(candidates.first?.isReachable, true)
    }

    func testListFallsBackToSavedServerForCustomDomainWithoutCurrentConnection() async throws {
        let apiClient = MockApiClient()

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: nil, isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let candidates = try await manager.listCandidates()

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.url, "nas.example.com")
        XCTAssertEqual(candidates.first?.type, .custom_domain)
        XCTAssertEqual(candidates.first?.isCurrent, false)
        XCTAssertEqual(candidates.first?.isReachable, true)
    }

    func testUsePersistsSelectedEndpointAndRefreshesSession() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.updateSession(sid: "old-sid", did: "old-did")

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let updated = try await manager.switchConnection(
            to: SynologyConnection(type: .relay, url: "https://relay.quickconnect.to:443")
        )

        XCTAssertEqual(updated.type, .relay)
        XCTAssertEqual(updated.url, "https://relay.quickconnect.to:443")
        XCTAssertEqual(apiClient.connection?.type, .relay)
        XCTAssertEqual(apiClient.connection?.url, "https://relay.quickconnect.to:443")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.relay.rawValue)
        XCTAssertEqual(apiClient.session?.sid, "new-sid")
        XCTAssertEqual(apiClient.session?.did, "new-did")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "new-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "new-did")
    }

    func testUseRejectsUnreachableSelectedEndpoint() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        do {
            _ = try await manager.switchConnection(
                to: SynologyConnection(type: .relay, url: "https://relay.quickconnect.to:443")
            )
            XCTFail("Expected unreachable endpoint failure")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "Selected endpoint is unreachable")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUseRollsBackConnectionAndSessionWhenSilentLoginFails() async {
        let apiClient = MockApiClient()
        apiClient.updateConnection(type: .lan, url: "https://192.168.1.10:5001")
        apiClient.updateSession(sid: "old-sid", did: "old-did")

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(onRefresh: {
                throw SynologyError.network(message: "refresh failed")
            }),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        do {
            _ = try await manager.switchConnection(
                to: SynologyConnection(type: .relay, url: "https://relay.quickconnect.to:443")
            )
            XCTFail("Expected switch failure")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "refresh failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(apiClient.session?.did, "old-did")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "old-did")
    }

    func testUseClearsSessionWhenRefreshFailsWithoutPreviousSession() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(onRefresh: {
                throw SynologyError.network(message: "refresh failed")
            }),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        do {
            _ = try await manager.switchConnection(
                to: SynologyConnection(type: .relay, url: "https://relay.quickconnect.to:443")
            )
            XCTFail("Expected switch failure")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "refresh failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(apiClient.session)
        XCTAssertNil(keychain.getSessionInfo())
    }

    func testRefreshQuickConnectEndpointReturnsNilWithoutCredentials() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "did", isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let connection = await manager.refreshQuickConnectEndpoint()

        XCTAssertNil(connection)
    }

    func testRefreshQuickConnectEndpointReturnsNilForCustomDomainCredentials() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "did", isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let connection = await manager.refreshQuickConnectEndpoint()

        XCTAssertNil(connection)
    }

    func testRefreshQuickConnectEndpointReturnsNilWhenResolvedEndpointIsUnreachable() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            audioStationApi: AudioStationClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "did", isPortalPort: false, sid: "sid"))),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let connection = await manager.refreshQuickConnectEndpoint()

        XCTAssertNil(connection)
        XCTAssertNil(apiClient.connection)
        XCTAssertNil(apiClient.session)
        XCTAssertNil(keychain.getConnectionInfo())
        XCTAssertNil(keychain.getSessionInfo())
    }
}

private final class RecordingPingPong: PingPongProviding, @unchecked Sendable {
    let firstResult: SynologyConnection?
    let singleURLReachable: Bool
    private let queue = DispatchQueue(label: "RecordingPingPong.state")
    private var storedSingleURLPings: [String] = []
    private var storedDidRunBestConnectionSelection = false

    var singleURLPings: [String] {
        queue.sync { storedSingleURLPings }
    }

    var didRunBestConnectionSelection: Bool {
        queue.sync { storedDidRunBestConnectionSelection }
    }

    init(firstResult: SynologyConnection?, singleURLReachable: Bool) {
        self.firstResult = firstResult
        self.singleURLReachable = singleURLReachable
    }

    func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String] {
        [:]
    }

    func pingpongFirst(connections: [ConnectionType: [String]]) async -> (type: ConnectionType, url: String)? {
        queue.sync {
            storedDidRunBestConnectionSelection = true
        }

        guard let firstResult else {
            return nil
        }
        return (firstResult.type, firstResult.url)
    }

    func pingpong(url: String) async -> Bool {
        queue.sync {
            storedSingleURLPings.append(url)
        }
        return singleURLReachable
    }
}

private func makeQuickConnectServerInfo(ip: String, port: Int) throws -> QuickConnectClient.ServerInfo {
    let json: [String: Any] = [
        "command": "get_server_info",
        "version": 1,
        "errno": 0,
        "server": [
            "interface": [
                [
                    "ip": ip,
                    "name": "eth0",
                    "mask": "255.255.255.0",
                ],
            ],
        ],
        "service": [
            "id": "dsm_https",
            "port": port,
        ],
    ]

    let data = try makeJSONData(json)
    return try JSONDecoder().decode(QuickConnectClient.ServerInfo.self, from: data)
}
