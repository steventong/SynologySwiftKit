import XCTest
@testable import SynologySwiftKit

final class AuthSessionRegressionTests: XCTestCase {
    func testSilentLoginWithExpiredCachedSessionFallsBackToFullLogin() async {
        let apiClient = MockApiClient()
        apiClient.connection = (.custom_domain, "https://nas.local")
        apiClient.session = ("expired-sid", nil)
        apiClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.DSM_INFO.name {
                throw SynologyError.sessionExpired(code: 106, message: "expired")
            }
            if endpoint.apiName == SynologyApi.Core.AUTH.name {
                return AuthResult(did: nil, isPortalPort: false, sid: "new-sid", synotoken: nil)
            }
            throw SynologyError.network(message: "Unexpected endpoint: \(endpoint.apiName)")
        }

        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.local", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveSessionInfo(sid: "expired-sid", did: nil)

        let authApi = AuthClient(apiClient: apiClient, keyChainStorage: keychain)
        let dsmInfoApi = DSMInfoClient(apiClient: apiClient)
        let connectionChecker = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: MockPingPong(singleURLReachable: true)),
            pingpong: MockPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )

        let login = SynologyUserLogin(
            apiInfoApi: MockApiInfoProvider(),
            apiClient: apiClient,
            authApi: authApi,
            dsmInfoApi: dsmInfoApi,
            connectionChecker: connectionChecker,
            keyChainStorage: keychain
        )

        var events: [SynologyUserLoginProgress] = []
        for await progress in login.login() {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 3)
        guard case .connecting = events[0] else {
            return XCTFail("Expected connecting progress first")
        }
        guard case .authenticating = events[1] else {
            return XCTFail("Expected authenticating progress second")
        }
        guard case let .completed(result) = events[2] else {
            return XCTFail("Expected completed after falling back to full login")
        }
        XCTAssertEqual(result.session.sid, "new-sid")

        // slice 校验确实发生过（缓存 SID 被验证并判定失效）
        // slice validation did happen (cached SID was checked and found invalid)
        XCTAssertTrue(apiClient.requestedEndpoints.contains { $0.apiName == SynologyApi.Core.DSM_INFO.name })
        // 全量登录成功后会话被刷新
        // session refreshed after successful full login
        XCTAssertEqual(apiClient.session?.sid, "new-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "new-sid")
    }

    func testResumeValidationFailuresNeverClearSIDOrPasswordLogin() async {
        let failures: [Error] = [
            SynologyError.network(message: "weak network"),
            SynologyError.network(message: "HTTP 502"),
            URLError(.timedOut),
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "invalid response")),
            SynologyError.sessionExpired(code: 0, message: "local session missing"),
            SynologyError.sessionExpired(code: 105, message: "not a server expiry"),
        ]
        for usedCachedConnection in [true, false] {
            for failure in failures {
                let apiClient = MockApiClient()
                let keychain = makeResumeStorage(apiClient: apiClient)
                apiClient.requestHandler = { endpoint in
                    XCTAssertEqual(endpoint.apiName, SynologyApi.Core.DSM_INFO.name)
                    XCTAssertEqual(apiClient.session?.sid, "old-sid")
                    throw failure
                }
                let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: usedCachedConnection)

                let events = await collectResumeEvents(login.login())

                XCTAssertEqual(events.count, 3, "\(failure), cache=\(usedCachedConnection)")
                guard case .failed = events.last else {
                    return XCTFail("Expected unavailable validation to end resume without login")
                }
                XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
                XCTAssertEqual(apiClient.clearSessionCount, 0)
                XCTAssertEqual(apiClient.session?.sid, "old-sid")
                XCTAssertEqual(apiClient.session?.did, "old-did")
                XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
                XCTAssertEqual(keychain.getSessionInfo()?.did, "old-did")
                XCTAssertEqual(apiClient.connection?.url, "https://old.local")
                XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://old.local")
            }
        }
    }

    func testResumeReusesSavedSIDOnRediscoveredAddress() async {
        let apiClient = MockApiClient()
        let keychain = makeResumeStorage(apiClient: apiClient)
        // 只有持久化 SID 的恢复也必须先把它加载到请求上下文，不能因换地址直接登录。
        apiClient.session = nil
        apiClient.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.apiName, SynologyApi.Core.DSM_INFO.name)
            XCTAssertEqual(apiClient.connection?.url, "https://new.local")
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            return makeResumeValidationInfo()
        }
        let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

        let events = await collectResumeEvents(login.login())

        guard case let .completed(result) = events.last else {
            return XCTFail("Expected original session to be reused on a rediscovered address")
        }
        XCTAssertEqual(result.session.sid, "old-sid")
        XCTAssertEqual(result.session.did, "old-did")
        XCTAssertEqual(result.connection.url, "https://new.local")
        XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
        XCTAssertEqual(apiClient.clearSessionCount, 0)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://new.local")
        XCTAssertEqual(apiClient.connection?.url, "https://new.local")
    }

    func testResumeReusesInMemorySIDWithoutPersistedSession() async {
        let apiClient = MockApiClient()
        let keychain = makeResumeStorage(apiClient: apiClient)
        keychain.removeSessionInfo()
        apiClient.mockResponse = makeResumeValidationInfo()
        let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

        let events = await collectResumeEvents(login.login())

        guard case let .completed(result) = events.last else {
            return XCTFail("Expected available in-memory SID to be reused")
        }
        XCTAssertEqual(result.session.sid, "old-sid")
        XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
        XCTAssertEqual(apiClient.clearSessionCount, 0)
    }

    func testResumeCancellationDuringValidationKeepsSIDAndDoesNotLogin() async {
        for failure: Error in [CancellationError(), URLError(.cancelled)] {
            let apiClient = MockApiClient()
            let keychain = makeResumeStorage(apiClient: apiClient)
            apiClient.mockError = failure
            let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

            let events = await collectResumeEvents(login.login())

            XCTAssertEqual(events.count, 2)
            XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
            XCTAssertEqual(apiClient.clearSessionCount, 0)
            XCTAssertEqual(apiClient.session?.sid, "old-sid")
            XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
            XCTAssertEqual(apiClient.connection?.url, "https://old.local")
        }
    }

    func testResumeTaskCancellationAfterValidationResponseKeepsSID() async {
        let apiClient = MockApiClient()
        let keychain = makeResumeStorage(apiClient: apiClient)
        apiClient.requestHandler = { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return makeResumeValidationInfo()
        }
        let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

        let events = await collectResumeEvents(login.login())

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
        XCTAssertEqual(apiClient.clearSessionCount, 0)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(apiClient.connection?.url, "https://old.local")
    }

    func testResumeAPIDiscoveryNetworkFailureKeepsSIDAndDoesNotLogin() async {
        let apiClient = MockApiClient()
        let keychain = makeResumeStorage(apiClient: apiClient)
        let login = makeResumeLogin(
            apiClient: apiClient,
            keychain: keychain,
            usedCachedConnection: false,
            apiInfo: TestApiInfoProvider(onRefresh: { throw SynologyError.network(message: "API discovery timeout") })
        )

        let events = await collectResumeEvents(login.login())

        guard case .failed = events.last else {
            return XCTFail("Expected discovery failure")
        }
        XCTAssertTrue(apiClient.requestedEndpoints.isEmpty)
        XCTAssertEqual(apiClient.clearSessionCount, 0)
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(apiClient.connection?.url, "https://old.local")
    }

    func testResumeServerExpiryOnRediscoveredAddressAllowsFullLogin() async {
        for code in [106, 107, 119] {
            let apiClient = MockApiClient()
            let keychain = makeResumeStorage(apiClient: apiClient)
            apiClient.requestHandler = { endpoint in
                if endpoint.apiName == SynologyApi.Core.DSM_INFO.name {
                    XCTAssertEqual(apiClient.session?.sid, "old-sid")
                    throw SynologyError.sessionExpired(code: code, message: "expired")
                }
                XCTAssertEqual(endpoint.apiName, SynologyApi.Core.AUTH.name)
                XCTAssertNil(apiClient.session)
                return AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid")
            }
            let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

            let events = await collectResumeEvents(login.login())

            guard case let .completed(result) = events.last else {
                return XCTFail("Expected explicit expiry to permit password login, code=\(code)")
            }
            XCTAssertEqual(result.session.sid, "new-sid")
            XCTAssertEqual(apiClient.requestedEndpoints.map(\.apiName), [SynologyApi.Core.DSM_INFO.name, SynologyApi.Core.AUTH.name])
            XCTAssertEqual(keychain.getSessionInfo()?.sid, "new-sid")
        }
    }

    func testExplicitPasswordLoginAndReloginRemainAvailable() async {
        for forceRelogin in [false, true] {
            let apiClient = MockApiClient()
            let keychain = makeResumeStorage(apiClient: apiClient)
            apiClient.requestHandler = { endpoint in
                XCTAssertEqual(endpoint.apiName, SynologyApi.Core.AUTH.name)
                return AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid")
            }
            let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)
            let stream = forceRelogin ? login.relogin() : login.login(server: "nas.local", username: "tester", password: "secret")

            let events = await collectResumeEvents(stream)

            guard case let .completed(result) = events.last else {
                return XCTFail("Expected explicit authentication to remain available")
            }
            XCTAssertEqual(result.session.sid, "new-sid")
            XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
            XCTAssertEqual(apiClient.clearSessionCount, 0)
        }
    }

    func testRenewalCredentialRejectionEndsInvalidSession() async {
        for forceRelogin in [false, true] {
            for code in [400, 401, 402, 405, 406, 407, 408, 409, 410, 411] {
                let apiClient = MockApiClient()
                let keychain = makeResumeStorage(apiClient: apiClient)
                apiClient.requestHandler = { endpoint in
                    if endpoint.apiName == SynologyApi.Core.DSM_INFO.name {
                        throw SynologyError.sessionExpired(code: 119, message: "expired")
                    }
                    throw SynologyError.auth(code: code, message: "credentials rejected")
                }
                let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

                let events = await collectResumeEvents(forceRelogin ? login.relogin() : login.login())

                guard case let .invalidSession(message) = events.last else {
                    return XCTFail("Expected known renewal rejection to require user login, code=\(code)")
                }
                XCTAssertEqual(message, "credentials rejected")
            }
        }
    }

    func testInitialPasswordCredentialRejectionKeepsFailureMessage() async {
        let apiClient = MockApiClient()
        let keychain = makeResumeStorage(apiClient: apiClient)
        apiClient.mockError = SynologyError.auth(code: 400, message: "wrong password")
        let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

        let events = await collectResumeEvents(login.login(server: "nas.local", username: "tester", password: "wrong"))

        guard case let .failed(message) = events.last else {
            return XCTFail("Expected first password login to retain ordinary failure")
        }
        XCTAssertEqual(message, "wrong password")
    }

    func testRenewalNetworkAndOrdinaryAPIFailuresKeepSession() async {
        let failures: [Error] = [
            SynologyError.network(message: "login timeout"),
            URLError(.notConnectedToInternet),
            CancellationError(),
            SynologyError.api(code: 109, message: "system busy"),
            SynologyError.sessionExpired(code: 0, message: "missing local SID"),
            SynologyError.auth(code: -1, message: "transport failed"),
        ]
        for forceRelogin in [false, true] {
            for failure in failures {
                let apiClient = MockApiClient()
                let keychain = makeResumeStorage(apiClient: apiClient)
                apiClient.requestHandler = { endpoint in
                    if endpoint.apiName == SynologyApi.Core.DSM_INFO.name {
                        throw SynologyError.sessionExpired(code: 106, message: "expired")
                    }
                    throw failure
                }
                let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

                let events = await collectResumeEvents(forceRelogin ? login.relogin() : login.login())

                if failure is CancellationError {
                    XCTAssertFalse(events.contains {
                        if case .failed = $0 { return true }
                        if case .completed = $0 { return true }
                        if case .invalidSession = $0 { return true }
                        return false
                    })
                } else {
                    guard case .failed = events.last else {
                        return XCTFail("Expected transport or unrelated API failure to preserve session: \(failure)")
                    }
                }
                XCTAssertEqual(apiClient.session?.sid, "old-sid")
                XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
                XCTAssertEqual(apiClient.connection?.url, "https://old.local")
            }
        }
    }

    func testRenewalOTPRejectionsKeepExistingOTPProgress() async {
        for forceRelogin in [false, true] {
            for code in [403, 404] {
                let apiClient = MockApiClient()
                let keychain = makeResumeStorage(apiClient: apiClient)
                apiClient.requestHandler = { endpoint in
                    if endpoint.apiName == SynologyApi.Core.DSM_INFO.name {
                        throw SynologyError.sessionExpired(code: 107, message: "expired")
                    }
                    throw SynologyError.auth(code: code, message: "OTP required")
                }
                let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

                let events = await collectResumeEvents(forceRelogin ? login.relogin() : login.login())

                guard case .otpRequired = events.last else {
                    return XCTFail("Expected OTP prompt, code=\(code)")
                }
            }
        }
    }

    func testAuthClientConvertedServerExpiryRemainsInvalidSession() async {
        let apiClient = MockApiClient()
        let keychain = makeResumeStorage(apiClient: apiClient)
        // AuthClient 会把服务器 sessionExpired 119 转成 auth 119，登录流程仍应识别真实失效。
        apiClient.mockError = SynologyError.sessionExpired(code: 119, message: "server invalid session")
        let login = makeResumeLogin(apiClient: apiClient, keychain: keychain, usedCachedConnection: false)

        let events = await collectResumeEvents(login.relogin())

        guard case .invalidSession = events.last else {
            return XCTFail("Expected normalized auth 119 to retain server expiry semantics")
        }
    }

    func testOnlyServerExpiryCodesAreClassifiedAsSessionExpiry() {
        for code in [106, 107, 119] {
            XCTAssertTrue(SynologyError.sessionExpired(code: code, message: "expired").isServerSessionExpired)
        }
        for code in [0, 100, 105, 109, 150, 400, 999] {
            XCTAssertFalse(SynologyError.sessionExpired(code: code, message: "other").isServerSessionExpired)
        }
        XCTAssertFalse(SynologyError.network(message: "HTTP 401").isServerSessionExpired)
        XCTAssertFalse(SynologyError.auth(code: 400, message: "invalid password").isServerSessionExpired)
    }

    func testLogoutClearsLocalSessionState() async throws {
        let apiClient = MockApiClient()
        apiClient.session = ("sid-123", "did-123")
        apiClient.mockResponse = EmptyData()

        let keychain = makeKeyChainStorage(service: UUID().uuidString)
        keychain.saveSessionInfo(sid: "sid-123", did: "did-123")

        let authApi = AuthClient(apiClient: apiClient, keyChainStorage: keychain)
        try await authApi.logout()

        XCTAssertNil(apiClient.session)
        XCTAssertNil(keychain.getSessionInfo())
    }
}

private func makeResumeStorage(apiClient: MockApiClient) -> any SensitiveStorage {
    let keychain = makeKeyChainStorage(service: UUID().uuidString)
    keychain.saveCredentials(server: "nas.local", username: "tester", password: "secret", usesHTTPS: true)
    keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
    keychain.saveConnectionInfo(url: "https://old.local", typeString: ConnectionType.custom_domain.rawValue)
    apiClient.connection = (.custom_domain, "https://old.local")
    apiClient.session = ("old-sid", "old-did")
    return keychain
}

private func makeResumeLogin(
    apiClient: MockApiClient,
    keychain: any SensitiveStorage,
    usedCachedConnection: Bool,
    apiInfo: any ApiInfoProviding = MockApiInfoProvider()
) -> SynologyUserLogin {
    SynologyUserLogin(
        apiInfoApi: apiInfo,
        apiClient: apiClient,
        authApi: AuthClient(apiClient: apiClient, keyChainStorage: keychain),
        dsmInfoApi: DSMInfoClient(apiClient: apiClient),
        connectionChecker: ResumeConnectionChecker(usedCachedConnection: usedCachedConnection),
        keyChainStorage: keychain
    )
}

private func collectResumeEvents(_ stream: AsyncStream<SynologyUserLoginProgress>) async -> [SynologyUserLoginProgress] {
    var events: [SynologyUserLoginProgress] = []
    for await event in stream {
        events.append(event)
    }
    return events
}

private struct ResumeConnectionChecker: ConnectionChecking {
    let usedCachedConnection: Bool

    func check() -> AsyncStream<ConnectionCheckProgress> {
        AsyncStream { continuation in
            continuation.yield(.success(connection: .init(type: .custom_domain, url: "https://new.local"), usedCachedConnection: usedCachedConnection))
            continuation.finish()
        }
    }

    func check(server: String) -> AsyncStream<ConnectionCheckProgress> { check() }
    func check(server: String, usesHTTPS: Bool) -> AsyncStream<ConnectionCheckProgress> { check() }
}

private func makeResumeValidationInfo() -> DsmInfo {
    DsmInfo(model: "DS920+")
}

private struct MockApiInfoProvider: ApiInfoProviding {
    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
        ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil)
    }

    func refresh() async throws {}

    func loadFromCacheOrRefresh() async throws {}
}

private struct MockPingPong: PingPongProviding {
    let singleURLReachable: Bool

    init(singleURLReachable: Bool = false) {
        self.singleURLReachable = singleURLReachable
    }

    func pingpong(connections: [ConnectionType: [String]]) async throws -> [ConnectionType: String] {
        [:]
    }

    func pingpongFirst(connections: [ConnectionType: [String]]) async throws -> (type: ConnectionType, url: String)? {
        nil
    }

    func pingpong(url: String) async throws -> Bool {
        singleURLReachable
    }
}
