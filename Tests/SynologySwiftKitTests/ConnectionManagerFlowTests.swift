import XCTest
@testable import SynologySwiftKit

final class ConnectionManagerFlowTests: XCTestCase {
    func testRecoverConnectionRestoresPersistedQuickConnectEndpointAndSchedulesOptimization() async {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://cached.local", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "sid", did: "did")
        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.DSM_INFO.name {
                return DsmInfo(model: "DS920+")
            }
            throw SynologyError.network(message: "Unexpected endpoint: \(endpoint.apiName)")
        }

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://cached.local")
    }

    func testRecoverConnectionWithUnreachableQuickConnectEndpointDisconnectsAndKeepsSession() async {
        let apiClient = MockApiClient()
        apiClient.mockError = SynologyError.network(message: "unreachable")
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://cached.local", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .disconnected)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
    }

    func testRecoverConnectionWithUnreachableCustomDomainDisconnects() async {
        let apiClient = MockApiClient()
        apiClient.mockError = SynologyError.network(message: "unreachable")
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://nas.example.com", typeString: ConnectionType.custom_domain.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .disconnected)
    }

    func testRecoverConnectionValidationFailuresKeepSessionAndDoNotLogin() async {
        let failures: [Error] = [
            SynologyError.network(message: "timeout"),
            SynologyError.network(message: "HTTP 503"),
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "invalid response")),
            URLError(.notConnectedToInternet),
            CancellationError(),
            SynologyError.sessionExpired(code: 0, message: "local SID missing"),
            SynologyError.sessionExpired(code: 105, message: "not an expiry code"),
        ]
        for failure in failures {
            let apiClient = MockApiClient()
            let keychain = makeRecoveryStorage(apiClient: apiClient)
            apiClient.mockError = failure
            let manager = makeRecoveryManager(apiClient: apiClient, keychain: keychain)

            let decision = await manager.recoverConnection()

            XCTAssertEqual(decision.status, .disconnected, "\(failure)")
            XCTAssertFalse(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.AUTH.name })
            XCTAssertEqual(apiClient.clearSessionCount, 0)
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
            XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        }
    }

    func testRecoverConnectionRequiresReloginOnlyForServerExpiryCodes() async {
        for code in [106, 107, 119] {
            let apiClient = MockApiClient()
            let keychain = makeRecoveryStorage(apiClient: apiClient)
            apiClient.mockError = SynologyError.sessionExpired(code: code, message: "expired")
            let manager = makeRecoveryManager(apiClient: apiClient, keychain: keychain)

            let decision = await manager.recoverConnection()

            XCTAssertEqual(decision.status, .requiresRelogin, "code=\(code)")
            XCTAssertFalse(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.AUTH.name })
            XCTAssertEqual(apiClient.clearSessionCount, 0)
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        }
    }

    func testRecoverConnectionRediscoversAddressWithoutReplacingSID() async {
        let apiClient = MockApiClient()
        let keychain = makeRecoveryStorage(apiClient: apiClient)
        let refreshed = SynologyConnection(type: .lan, url: "https://192.168.1.20:5001")
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }
        apiClient.requestHandler = { _ in
            if apiClient.connection?.url != refreshed.url { throw SynologyError.network(message: "unreachable") }
            XCTAssertEqual(apiClient.connection?.url, refreshed.url)
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            return makeSessionValidationInfo()
        }
        let manager = makeRecoveryManager(
            apiClient: apiClient,
            keychain: keychain,
            pingpong: RecordingPingPong(firstResult: refreshed, singleURLReachable: false)
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertFalse(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.AUTH.name })
        XCTAssertEqual(apiClient.clearSessionCount, 0)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, refreshed.url)
    }

    func testRediscoveredEndpointValidationFailuresKeepSIDAndDisconnect() async {
        for failure in [
            SynologyError.network(message: "weak network"),
            SynologyError.sessionExpired(code: 0, message: "local SID missing"),
        ] {
            let apiClient = MockApiClient()
            let keychain = makeRecoveryStorage(apiClient: apiClient)
            apiClient.rawRequestHandler = { _, _, _, _, _ in
                try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
            }
            apiClient.mockError = failure
            let manager = makeRecoveryManager(
                apiClient: apiClient,
                keychain: keychain,
                pingpong: RecordingPingPong(firstResult: .init(type: .lan, url: "https://192.168.1.20:5001"), singleURLReachable: false)
            )

            let decision = await manager.recoverConnection()

            XCTAssertEqual(decision.status, .disconnected)
            XCTAssertFalse(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.AUTH.name })
            XCTAssertEqual(apiClient.clearSessionCount, 0)
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
            XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.10:5001")
            XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        }
    }

    func testSwitchConnectionReportsServerExpiryWithoutAuthenticating() async {
        for code in [106, 107, 119] {
            let apiClient = MockApiClient()
            let keychain = makeRecoveryStorage(apiClient: apiClient)
            apiClient.requestHandler = { _ in
                XCTAssertEqual(apiClient.session?.sid, "old-sid")
                throw SynologyError.sessionExpired(code: code, message: "expired")
            }
            let manager = makeRecoveryManager(apiClient: apiClient, keychain: keychain)

            do {
                _ = try await manager.switchConnection(to: .init(type: .relay, url: "https://relay.quickconnect.to"))
                XCTFail("Expected server expiry")
            } catch let SynologyError.sessionExpired(actualCode, _) {
                XCTAssertEqual(actualCode, code)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

            XCTAssertFalse(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.AUTH.name })
            XCTAssertEqual(apiClient.clearSessionCount, 0)
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
            XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.10:5001")
        }
    }

    func testRediscoveredEndpointServerExpiryRequiresReloginWithoutAuthenticating() async {
        for code in [106, 107, 119] {
            let apiClient = MockApiClient()
            let keychain = makeRecoveryStorage(apiClient: apiClient)
            apiClient.rawRequestHandler = { _, _, _, _, _ in
                try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
            }
            apiClient.mockError = SynologyError.sessionExpired(code: code, message: "expired")
            let manager = makeRecoveryManager(
                apiClient: apiClient,
                keychain: keychain,
                pingpong: RecordingPingPong(firstResult: .init(type: .lan, url: "https://192.168.1.20:5001"), singleURLReachable: false)
            )

            let decision = await manager.recoverConnection()

            XCTAssertEqual(decision.status, .requiresRelogin, "code=\(code)")
            XCTAssertFalse(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.AUTH.name })
            XCTAssertEqual(apiClient.clearSessionCount, 0)
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        }
    }

    func testBackgroundOptimizationReusesSIDWithoutLogin() async {
        let apiClient = MockApiClient()
        let keychain = makeRecoveryStorage(apiClient: apiClient)
        apiClient.mockResponse = makeSessionValidationInfo()
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }
        let scheduler = BackgroundRecoveryOptimizationScheduler()
        let manager = makeRecoveryManager(
            apiClient: apiClient,
            keychain: keychain,
            pingpong: RecordingPingPong(firstResult: .init(type: .lan, url: "https://192.168.1.20:5001"), singleURLReachable: true),
            scheduler: scheduler
        )

        let decision = await manager.recoverConnection()
        await scheduler.waitForCompletion()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertFalse(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.AUTH.name })
        XCTAssertEqual(apiClient.clearSessionCount, 0)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(apiClient.requestedEndpoints.filter { $0.apiName == SynologyApi.Core.DSM_INFO.name }.count, 2)
    }

    func testBackgroundOptimizationKeepsValidatedEndpointWithoutAnotherSessionRequest() async {
        let apiClient = MockApiClient()
        let keychain = makeRecoveryStorage(apiClient: apiClient)
        apiClient.mockResponse = makeSessionValidationInfo()
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.10", port: 5001)
        }
        let scheduler = BackgroundRecoveryOptimizationScheduler()
        let manager = makeRecoveryManager(
            apiClient: apiClient,
            keychain: keychain,
            pingpong: RecordingPingPong(firstResult: .init(type: .lan, url: "https://192.168.1.10:5001"), singleURLReachable: true),
            scheduler: scheduler
        )

        let decision = await manager.recoverConnection()
        await scheduler.waitForCompletion()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertFalse(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.AUTH.name })
        XCTAssertEqual(apiClient.clearSessionCount, 0)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(apiClient.requestedEndpoints.filter { $0.apiName == SynologyApi.Core.DSM_INFO.name }.count, 1)
    }

    func testRecoverConnectionWithoutCredentialsDisconnects() async {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .disconnected)
    }

    func testOptimizeQuickConnectEndpointPersistsRefreshedConnectionWithOriginalSession() async throws {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.requestHandler = { _ in
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            return makeSessionValidationInfo()
        }
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let refreshed = SynologyConnection(type: .lan, url: "https://192.168.1.20:5001")
        let pingpong = RecordingPingPong(firstResult: refreshed, singleURLReachable: true)
        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let connection = await manager.refreshQuickConnectEndpoint()

        XCTAssertEqual(connection?.type, .lan)
        XCTAssertEqual(connection?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(apiClient.session?.did, "old-did")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "old-did")
        XCTAssertTrue(pingpong.singleURLPings.isEmpty)
    }

    func testRecoverConnectionKeepsReachableQuickConnectEndpointAndSkipsSynchronousOptimization() async throws {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
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
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.DSM_INFO.name {
                return DsmInfo(model: "DS920+")
            }
            throw SynologyError.network(message: "Unexpected endpoint: \(endpoint.apiName)")
        }

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertTrue(pingpong.singleURLPings.isEmpty)
        XCTAssertFalse(pingpong.didRunBestConnectionSelection)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(apiClient.session?.did, "old-did")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
    }

    func testRecoverConnectionRequiresReloginWhenReachableEndpointHasInvalidSession() async throws {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "expired-sid", did: "old-did")
        apiClient.updateSession(sid: "expired-sid", did: "old-did")

        let pingpong = RecordingPingPong(firstResult: nil, singleURLReachable: true)
        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.DSM_INFO.name {
                throw SynologyError.sessionExpired(code: 106, message: "expired")
            }
            throw SynologyError.network(message: "Unexpected endpoint: \(endpoint.apiName)")
        }

        let decision = await manager.recoverConnection()

        XCTAssertEqual(decision.status, .requiresRelogin)
        XCTAssertTrue(pingpong.singleURLPings.isEmpty)
    }

    func testOptimizeQuickConnectEndpointDoesNotPersistRefreshedConnectionWhenValidationFails() async throws {
        let apiClient = MockApiClient()
        apiClient.updateConnection(type: .lan, url: "https://192.168.1.10:5001")
        apiClient.updateSession(sid: "old-sid", did: "old-did")
        apiClient.mockError = SynologyError.network(message: "validation timed out")

        let keychain = makeKeyChainStorage(service: UUID().uuidString)
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
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
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
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.10", port: 5001)
        }

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
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

        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
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

        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
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

    func testUsePersistsSelectedEndpointAndReusesSession() async throws {
        let apiClient = MockApiClient()
        apiClient.mockResponse = makeSessionValidationInfo()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.updateSession(sid: "old-sid", did: "old-did")

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
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
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(apiClient.session?.did, "old-did")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "old-did")
    }

    func testUseRejectsUnreachableSelectedEndpoint() async {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        do {
            _ = try await manager.switchConnection(
                to: SynologyConnection(type: .relay, url: "https://relay.quickconnect.to:443")
            )
            XCTFail("Expected unreachable endpoint failure")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "Missing saved session")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUseRollsBackConnectionAndSessionWhenAPIDiscoveryFails() async {
        let apiClient = MockApiClient()
        apiClient.updateConnection(type: .lan, url: "https://192.168.1.10:5001")
        apiClient.updateSession(sid: "old-sid", did: "old-did")

        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(onLoad: {
                throw SynologyError.network(message: "refresh failed")
            }),
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

    func testUseRejectsMissingSessionWithoutLoggingIn() async {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(onLoad: {
                throw SynologyError.network(message: "refresh failed")
            }),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        do {
            _ = try await manager.switchConnection(
                to: SynologyConnection(type: .relay, url: "https://relay.quickconnect.to:443")
            )
            XCTFail("Expected switch failure")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "Missing saved session")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(apiClient.session)
        XCTAssertNil(keychain.getSessionInfo())
    }

    func testRefreshQuickConnectEndpointReturnsNilWithoutCredentials() async {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let connection = await manager.refreshQuickConnectEndpoint()

        XCTAssertNil(connection)
    }

    func testRefreshQuickConnectEndpointReturnsNilForCustomDomainCredentials() async {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
            optimizationScheduler: NoOpQuickConnectOptimizationScheduler(),
            keyChainStorage: keychain
        )

        let connection = await manager.refreshQuickConnectEndpoint()

        XCTAssertNil(connection)
    }

    func testRefreshQuickConnectEndpointReturnsNilWhenResolvedEndpointIsUnreachable() async throws {
        let apiClient = MockApiClient()
        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let manager = ConnectionManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            dsmInfoApi: DSMInfoClient(apiClient: apiClient),
            apiInfoApi: TestApiInfoProvider(),
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

private func makeRecoveryStorage(apiClient: MockApiClient) -> any SensitiveStorage {
    let keychain = makeKeyChainStorage(service: UUID().uuidString)
    keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
    keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
    keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
    apiClient.updateConnection(type: .lan, url: "https://192.168.1.10:5001")
    apiClient.updateSession(sid: "old-sid", did: "old-did")
    return keychain
}

private func makeRecoveryManager(
    apiClient: MockApiClient,
    keychain: any SensitiveStorage,
    pingpong: any PingPongProviding = TestPingPong(singleURLReachable: true),
    scheduler: any QuickConnectOptimizationScheduling = NoOpQuickConnectOptimizationScheduler()
) -> ConnectionManager {
    ConnectionManager(
        apiClient: apiClient,
        quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
        pingpong: pingpong,
        dsmInfoApi: DSMInfoClient(apiClient: apiClient),
        apiInfoApi: TestApiInfoProvider(),
        optimizationScheduler: scheduler,
        keyChainStorage: keychain
    )
}

private actor BackgroundRecoveryOptimizationScheduler: QuickConnectOptimizationScheduling {
    private var task: Task<QuickConnectEndpointRefreshOutcome, Never>?
    func run(operation: @escaping @Sendable () async -> QuickConnectEndpointRefreshOutcome) async -> QuickConnectEndpointRefreshOutcome {
        await operation()
    }

    func schedule(operation: @escaping @Sendable () async -> QuickConnectEndpointRefreshOutcome) async {
        task = Task { await operation() }
    }

    func waitForCompletion() async {
        _ = await task?.value
    }
}

private func makeSessionValidationInfo() -> DsmInfo {
    DsmInfo(model: "DS920+")
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

    func pingpong(connections: [ConnectionType: [String]]) async throws -> [ConnectionType: String] {
        [:]
    }

    func pingpongFirst(connections: [ConnectionType: [String]]) async throws -> (type: ConnectionType, url: String)? {
        queue.sync {
            storedDidRunBestConnectionSelection = true
        }

        guard let firstResult else {
            return nil
        }
        return (firstResult.type, firstResult.url)
    }

    func pingpong(url: String) async throws -> Bool {
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
