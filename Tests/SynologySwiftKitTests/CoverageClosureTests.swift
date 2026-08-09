import XCTest
@testable import SynologySwiftKit

private final class LogCaptureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var records: [SynologyLogRecord] = []

    func append(_ record: SynologyLogRecord) {
        lock.lock()
        records.append(record)
        lock.unlock()
    }

    func snapshot() -> [SynologyLogRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }
}

final class CoverageClosureTests: XCTestCase {
    func testLoggerAndJsonUtilsCoverSuccessAndFailurePaths() {
        let capture = LogCaptureBox()
        Logger.isEnabled = true
        Logger.destination = .handler
        Logger.handler = { capture.append($0) }

        SynologySwiftKit.Logger.info("info")
        SynologySwiftKit.Logger.debug("debug")
        SynologySwiftKit.Logger.warn("warn")
        SynologySwiftKit.Logger.error("error")

        Logger.isEnabled = false
        SynologySwiftKit.Logger.info("disabled")
        Logger.destination = .system
        Logger.handler = nil
        Logger.isEnabled = true

        let captured = capture.snapshot()
        XCTAssertEqual(captured.map(\.level), [.info, .debug, .warning, .error])
        XCTAssertEqual(captured.map(\.message), ["info", "debug", "warn", "error"])

        XCTAssertEqual(JsonUtils.toJson(codable: EncodableValue(value: "ok")), #"{"value":"ok"}"#)
        XCTAssertNil(JsonUtils.toJson(codable: ThrowingCodable()))
    }

    func testSynologyErrorHelpersAndDescriptions() {
        XCTAssertEqual(SynologyError.network(message: "offline").errorDescription, "offline")
        XCTAssertEqual(SynologyError.api(code: 102, message: "missing").errorDescription, "API error (102): missing")
        XCTAssertEqual(SynologyError.sessionExpired(code: 105, message: "expired").errorDescription, "Session expired: expired")
        XCTAssertEqual(SynologyError.auth(code: 403, message: "otp").errorDescription, "otp")

        guard case let .auth(code, message) = SynologyError.authError(code: 401) else {
            return XCTFail("Expected auth error")
        }
        XCTAssertEqual(code, 401)
        XCTAssertEqual(message, Localization.text("DISABLED_ACCOUNT"))

        guard case let .auth(customCode, customMessage) = SynologyError.authError(code: 499, message: "custom") else {
            return XCTFail("Expected custom auth error")
        }
        XCTAssertEqual(customCode, 499)
        XCTAssertEqual(customMessage, "custom")
    }

    func testApiParametersBuilderStaticBranches() {
        let tuple = ApiParametersBuilder.buildExpression(("limit", 10))
        let emptyTuple = ApiParametersBuilder.buildExpression(("keyword", nil as String?))
        let dictionary = ApiParametersBuilder.buildExpression(["library": .string("shared")])
        let voidResult = ApiParametersBuilder.buildExpression(())
        let optionalNil = ApiParametersBuilder.buildOptional(nil)
        let eitherFirst = ApiParametersBuilder.buildEither(first: ["a": .string("1")])
        let eitherSecond = ApiParametersBuilder.buildEither(second: ["b": .string("2")])
        let array = ApiParametersBuilder.buildArray([["x": .string("1")], ["y": .string("2")]])
        let block = ApiParametersBuilder.buildBlock(tuple, dictionary, eitherFirst, eitherSecond, array)

        XCTAssertEqual(tuple["limit"]?.stringValue, "10")
        XCTAssertTrue(emptyTuple.isEmpty)
        XCTAssertEqual(dictionary["library"]?.stringValue, "shared")
        XCTAssertTrue(voidResult.isEmpty)
        XCTAssertTrue(optionalNil.isEmpty)
        XCTAssertEqual(block["a"]?.stringValue, "1")
        XCTAssertEqual(block["b"]?.stringValue, "2")
        XCTAssertEqual(block["x"]?.stringValue, "1")
        XCTAssertEqual(block["y"]?.stringValue, "2")
    }

    func testKeyChainStorageSupportsAllStoredPayloads() {
        let service = UUID().uuidString
        let keychain = makeKeyChainStorage(service: service)

        XCTAssertNil(keychain.getCredentials())
        XCTAssertNil(keychain.getSessionInfo())
        XCTAssertNil(keychain.getConnectionInfo())
        XCTAssertNil(keychain.getDeviceInfo())

        keychain.saveCredentials(server: "nas.local", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveSessionInfo(sid: "sid-1", did: "did-1")
        keychain.saveConnectionInfo(url: "https://nas.local", typeString: ConnectionType.lan.rawValue)
        keychain.saveDeviceInfo("device-1", "iPhone")

        XCTAssertEqual(keychain.getCredentials()?.server, "nas.local")
        XCTAssertEqual(keychain.getCredentials()?.username, "tester")
        XCTAssertEqual(keychain.getCredentials()?.password, "secret")
        XCTAssertEqual(keychain.getCredentials()?.usesHTTPS, true)
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "sid-1")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "did-1")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://nas.local")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
        XCTAssertEqual(keychain.getDeviceInfo()?.0, "device-1")
        XCTAssertEqual(keychain.getDeviceInfo()?.1, "iPhone")

        keychain.removeCredentials()
        keychain.removeSessionInfo()
        keychain.removeConnectionInfo()

        XCTAssertNil(keychain.getCredentials())
        XCTAssertNil(keychain.getSessionInfo())
        XCTAssertNil(keychain.getConnectionInfo())
        XCTAssertNotNil(keychain.getDeviceInfo())
    }

    func testAuthInterceptorCoversGuardAndPassthroughBranches() async {
        let emptyInterceptor = AuthInterceptor(sessionProvider: { nil }, onSessionExpired: nil)
        let sidEndpoint = ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "cover", sidOnQuery: true)
        let cookieEndpoint = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", sidOnCookie: true)

        do {
            _ = try await emptyInterceptor.adapt(URLRequest(url: URL(string: "https://nas.local")!), for: sidEndpoint)
            XCTFail("Expected missing sid to throw")
        } catch let SynologyError.sessionExpired(code, _) {
            XCTAssertEqual(code, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        var postWithSid = URLRequest(url: URL(string: "https://nas.local/webapi")!)
        postWithSid.httpMethod = "POST"
        postWithSid.httpBody = "_sid=existing".data(using: .utf8)
        let sidInterceptor = AuthInterceptor(sessionProvider: { ("sid-1", nil) }, onSessionExpired: nil)
        let adaptedPost = try? await sidInterceptor.adapt(postWithSid, for: sidEndpoint)
        XCTAssertEqual(String(data: adaptedPost?.httpBody ?? Data(), encoding: .utf8), "_sid=existing")

        var cookieRequest = URLRequest(url: URL(string: "https://nas.local/webapi")!)
        cookieRequest.httpMethod = "GET"
        cookieRequest.setValue("foo=bar; id=existing", forHTTPHeaderField: "Cookie")
        let adaptedCookie = try? await sidInterceptor.adapt(cookieRequest, for: cookieEndpoint)
        XCTAssertEqual(adaptedCookie?.value(forHTTPHeaderField: "Cookie"), "foo=bar; id=existing")

        var expired = false
        let callbackInterceptor = AuthInterceptor(sessionProvider: { ("sid-2", nil) }, onSessionExpired: { expired = true })
        _ = try? await callbackInterceptor.process(.failure(SynologyError.api(code: 102, message: "not expired")), for: cookieEndpoint)
        XCTAssertFalse(expired)
    }

    func testDSMInfoClientSuccessAndErrorMapping() async throws {
        let successClient = MockApiClient()
        successClient.mockResponse = DsmInfo(
            codepage: "chs",
            model: "DS920+",
            ram: 8192,
            serial: "serial",
            temperature: 40,
            temperatureWarn: false,
            time: "now",
            uptime: 1,
            version: "7.2",
            versionString: "DSM 7.2"
        )
        let api = DSMInfoClient(apiClient: successClient)
        let dsmInfo = try await api.query()
        XCTAssertEqual(dsmInfo.model, "DS920+")

        let synologyErrorClient = MockApiClient()
        synologyErrorClient.mockError = SynologyError.api(code: 101, message: "bad")
        do {
            _ = try await DSMInfoClient(apiClient: synologyErrorClient).query()
            XCTFail("Expected synology error")
        } catch let SynologyError.api(code, _) {
            XCTAssertEqual(code, 101)
        }

        let genericErrorClient = MockApiClient()
        genericErrorClient.mockError = URLError(.timedOut)
        do {
            _ = try await DSMInfoClient(apiClient: genericErrorClient).query()
            XCTFail("Expected mapped network error")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "request failed")
        }
    }

    func testAuthClientLoginMapsErrorsAndPersistsDeviceInfo() async throws {
        let service = UUID().uuidString
        let keychain = makeKeyChainStorage(service: service)
        let successClient = MockApiClient()
        successClient.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.parameters["account"]?.stringValue, "tester")
            XCTAssertEqual(endpoint.parameters["passwd"]?.stringValue, "secret")
            XCTAssertEqual(endpoint.parameters["enable_device_token"]?.stringValue, "yes")
            XCTAssertEqual(endpoint.parameters["otp_code"]?.stringValue, "123456")
            XCTAssertNotNil(Int(endpoint.parameters["client_time"]?.stringValue ?? ""))
            XCTAssertNil(endpoint.parameters["enable_syno_token"])
            XCTAssertNil(endpoint.parameters["device_id"])
            XCTAssertNil(endpoint.parameters["device_name"])
            return AuthResult(did: "device-1", isPortalPort: false, sid: "sid-1", synotoken: nil)
        }

        let api = AuthClient(apiClient: successClient, keyChainStorage: keychain)
        let result = try await api.login(username: "tester", password: "secret", otpCode: "123456")
        XCTAssertEqual(result.sid, "sid-1")
        XCTAssertEqual(keychain.getDeviceInfo()?.0, "device-1")

        let trustedDeviceClient = MockApiClient()
        trustedDeviceClient.requestHandler = { endpoint in
            XCTAssertNil(endpoint.parameters["otp_code"])
            XCTAssertNil(endpoint.parameters["enable_device_token"])
            XCTAssertEqual(endpoint.parameters["device_id"]?.stringValue, "device-1")
            XCTAssertEqual(endpoint.parameters["device_name"]?.stringValue, "Apple Device - DS Music")
            return AuthResult(did: nil, isPortalPort: false, sid: "sid-2", synotoken: nil)
        }
        _ = try await AuthClient(
            apiClient: trustedDeviceClient,
            keyChainStorage: keychain
        ).login(username: "tester", password: "secret", otpCode: "  ")

        let sessionExpiredClient = MockApiClient()
        sessionExpiredClient.mockError = SynologyError.sessionExpired(code: 403, message: "otp")
        do {
            _ = try await AuthClient(apiClient: sessionExpiredClient, keyChainStorage: keychain).login(username: "tester", password: "secret")
            XCTFail("Expected auth conversion")
        } catch let SynologyError.auth(code, message) {
            XCTAssertEqual(code, 403)
            XCTAssertEqual(message, "otp")
        }

        let apiErrorClient = MockApiClient()
        apiErrorClient.mockError = SynologyError.api(code: 404, message: "bad")
        do {
            _ = try await AuthClient(apiClient: apiErrorClient, keyChainStorage: keychain).login(username: "tester", password: "secret")
            XCTFail("Expected authError conversion")
        } catch let SynologyError.auth(code, message) {
            XCTAssertEqual(code, 404)
            XCTAssertEqual(message, Localization.text("AUTHENTICATION_CODE_FAILED"))
        }

        let genericErrorClient = MockApiClient()
        genericErrorClient.mockError = URLError(.cannotConnectToHost)
        do {
            _ = try await AuthClient(apiClient: genericErrorClient, keyChainStorage: keychain).login(username: "tester", password: "secret")
            XCTFail("Expected fallback auth error")
        } catch let SynologyError.auth(code, message) {
            XCTAssertEqual(code, -1)
            XCTAssertTrue(message.contains("login failed"))
        }
    }

    func testSynologyClientCoversSessionConnectionAndInterceptorPaths() async throws {
        let service = UUID().uuidString
        let keychain = makeKeyChainStorage(service: service)
        let transport = HTTPClientFactorySpy()
        let apiClient = ApiClient(httpClientFactory: transport.makeFactory())
        let client = SynologyClient(
            config: .default,
            keyValueStorage: MockKeyValueStorage(),
            keyChainStorage: keychain,
            apiClient: apiClient
        )

        XCTAssertNil(client.session.connection)
        XCTAssertFalse(client.session.hasValidSession)

        client.apiClient.updateConnection(type: .lan, url: "https://nas.local")
        XCTAssertEqual(client.session.connection?.type, .lan)

        client.session.update(sid: "sid-1", did: "did-1")
        XCTAssertTrue(client.session.hasValidSession)
        XCTAssertEqual(client.session.current?.did, "did-1")

        let testInterceptor = HeaderAppendingInterceptor()
        client.addInterceptor(testInterceptor)

        transport.handler = { request, _ in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test"), "1")
            let payload = try JSONEncoder().encode(SimplePayload(ok: true))
            return (payload, makeHTTPURLResponse(url: request.url!))
        }

        let payload: SimplePayload = try await client.apiClient.request(url: URL(string: "https://nas.local/raw")!)
        XCTAssertTrue(payload.ok)
    }

    func testSynologyUserLoginCoversCredentialRemovalAndErrorBranches() async {
        let removeKeychain = makeKeyChainStorage(service: UUID().uuidString)
        removeKeychain.saveCredentials(server: "nas.local", username: "tester", password: "old", usesHTTPS: true)
        let removeClient = MockApiClient()
        removeClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.AUTH.name {
                return AuthResult(did: "device-1", isPortalPort: false, sid: "sid-1", synotoken: nil)
            }
            throw SynologyError.network(message: "Unexpected endpoint")
        }

        let removeAuthApi = AuthClient(apiClient: removeClient, keyChainStorage: removeKeychain)
        let removeAudioStationApi = AudioStationClient(apiClient: removeClient)
        let removeConnectionChecker = ConnectionChecker(
            apiClient: removeClient,
            quickConnectApi: QuickConnectClient(apiClient: removeClient, pingpong: TestPingPong(singleURLReachable: true)),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: removeKeychain
        )
        let removeLogin = SynologyUserLogin(
            apiInfoApi: TestApiInfoProvider(),
            apiClient: removeClient,
            authApi: removeAuthApi,
            audioStationApi: removeAudioStationApi,
            connectionChecker: removeConnectionChecker,
            keyChainStorage: removeKeychain
        )

        var removeEvents: [SynologyUserLoginProgress] = []
        for await progress in removeLogin.login(server: "https://nas.local", username: "tester", password: "secret", shouldSavePassword: false) {
            removeEvents.append(progress)
        }
        guard case .completed = removeEvents.last else {
            return XCTFail("Expected completed login")
        }
        XCTAssertNil(removeKeychain.getCredentials())

        let otpKeychain = makeKeyChainStorage(service: UUID().uuidString)
        let otpClient = MockApiClient()
        otpClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.AUTH.name {
                throw SynologyError.auth(code: 403, message: "otp required")
            }
            throw SynologyError.network(message: "Unexpected endpoint")
        }

        let otpAuthApi = AuthClient(apiClient: otpClient, keyChainStorage: otpKeychain)
        let otpAudioStationApi = AudioStationClient(apiClient: otpClient)
        let otpConnectionChecker = ConnectionChecker(
            apiClient: otpClient,
            quickConnectApi: QuickConnectClient(apiClient: otpClient, pingpong: TestPingPong(singleURLReachable: true)),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: otpKeychain
        )
        let otpLogin = SynologyUserLogin(
            apiInfoApi: TestApiInfoProvider(),
            apiClient: otpClient,
            authApi: otpAuthApi,
            audioStationApi: otpAudioStationApi,
            connectionChecker: otpConnectionChecker,
            keyChainStorage: otpKeychain
        )

        var otpEvents: [SynologyUserLoginProgress] = []
        for await progress in otpLogin.login(server: "https://nas.local", username: "tester", password: "secret") {
            otpEvents.append(progress)
        }
        guard case .otpRequired? = otpEvents.last else {
            return XCTFail("Expected otpRequired")
        }
        XCTAssertNil(otpKeychain.getCredentials())

        otpClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.AUTH.name {
                throw SynologyError.auth(code: 404, message: "otp invalid")
            }
            throw SynologyError.network(message: "Unexpected endpoint")
        }
        var invalidOTPEvents: [SynologyUserLoginProgress] = []
        for await progress in otpLogin.login(
            server: "https://nas.local",
            username: "tester",
            password: "secret",
            otpCode: "000000"
        ) {
            invalidOTPEvents.append(progress)
        }
        guard case .otpRequired? = invalidOTPEvents.last else {
            return XCTFail("Expected otpRequired after invalid OTP")
        }

        let missingClient = MockApiClient()
        let missingKeychain = makeKeyChainStorage(service: UUID().uuidString)
        let missingAuthApi = AuthClient(apiClient: missingClient, keyChainStorage: missingKeychain)
        let missingAudioStationApi = AudioStationClient(apiClient: missingClient)
        let missingConnectionChecker = ConnectionChecker(
            apiClient: missingClient,
            quickConnectApi: QuickConnectClient(apiClient: missingClient, pingpong: TestPingPong(singleURLReachable: true)),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: missingKeychain
        )
        let missingLogin = SynologyUserLogin(
            apiInfoApi: TestApiInfoProvider(),
            apiClient: missingClient,
            authApi: missingAuthApi,
            audioStationApi: missingAudioStationApi,
            connectionChecker: missingConnectionChecker,
            keyChainStorage: missingKeychain
        )

        var missingEvents: [SynologyUserLoginProgress] = []
        for await progress in missingLogin.login() {
            missingEvents.append(progress)
        }
        guard case let .invalidSession(message)? = missingEvents.last else {
            return XCTFail("Expected invalidSession")
        }
        XCTAssertTrue(message.contains("No saved credentials"))

        struct FailingApiInfoProvider: ApiInfoProviding {
            func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
                ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil)
            }

            func refresh() async throws {
                throw SynologyError.network(message: "api info failed")
            }

            func loadFromCacheOrRefresh() async throws {
                try await refresh()
            }
        }

        let failureClient = MockApiClient()
        let failureKeychain = makeKeyChainStorage(service: UUID().uuidString)
        let failureAuthApi = AuthClient(apiClient: failureClient, keyChainStorage: failureKeychain)
        let failureAudioStationApi = AudioStationClient(apiClient: failureClient)
        let failureConnectionChecker = ConnectionChecker(
            apiClient: failureClient,
            quickConnectApi: QuickConnectClient(apiClient: failureClient, pingpong: TestPingPong(singleURLReachable: true)),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: failureKeychain
        )
        let failureLogin = SynologyUserLogin(
            apiInfoApi: FailingApiInfoProvider(),
            apiClient: failureClient,
            authApi: failureAuthApi,
            audioStationApi: failureAudioStationApi,
            connectionChecker: failureConnectionChecker,
            keyChainStorage: failureKeychain
        )

        var failureEvents: [SynologyUserLoginProgress] = []
        for await progress in failureLogin.login(server: "https://nas.local", username: "tester", password: "secret") {
            failureEvents.append(progress)
        }
        guard case let .failed(message)? = failureEvents.last else {
            return XCTFail("Expected failed event")
        }
        XCTAssertTrue(message.contains("api info failed"))
        XCTAssertNil(failureKeychain.getCredentials())

        let preservedKeychain = makeKeyChainStorage(service: UUID().uuidString)
        preservedKeychain.saveCredentials(
            server: "old-nas.local",
            username: "old-user",
            password: "old-password",
            usesHTTPS: true
        )
        let preservedClient = MockApiClient()
        let preservedLogin = SynologyUserLogin(
            apiInfoApi: FailingApiInfoProvider(),
            apiClient: preservedClient,
            authApi: AuthClient(apiClient: preservedClient, keyChainStorage: preservedKeychain),
            audioStationApi: AudioStationClient(apiClient: preservedClient),
            connectionChecker: ConnectionChecker(
                apiClient: preservedClient,
                quickConnectApi: QuickConnectClient(
                    apiClient: preservedClient,
                    pingpong: TestPingPong(singleURLReachable: true)
                ),
                pingpong: TestPingPong(singleURLReachable: true),
                keyChainStorage: preservedKeychain
            ),
            keyChainStorage: preservedKeychain
        )

        for await _ in preservedLogin.login(
            server: "https://new-nas.local",
            username: "new-user",
            password: "wrong-password",
            shouldSavePassword: false
        ) {}

        XCTAssertEqual(
            preservedKeychain.getCredentials(),
            SynologyCredentials(
                server: "old-nas.local",
                username: "old-user",
                password: "old-password",
                usesHTTPS: true
            )
        )
    }
}

private struct EncodableValue: Codable {
    let value: String
}

private struct ThrowingCodable: Codable {
    func encode(to encoder: Encoder) throws {
        throw EncodingFailure.error
    }

    init() {}

    init(from decoder: Decoder) throws {
        self.init()
    }

    private enum EncodingFailure: Error {
        case error
    }
}

private struct HeaderAppendingInterceptor: SynologyRequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        request.setValue("1", forHTTPHeaderField: "X-Test")
        return request
    }

    func process(_ result: Result<(Data, URLResponse), Error>) async throws -> Result<(Data, URLResponse), Error> {
        result
    }
}

private struct SimplePayload: Codable {
    let ok: Bool
}
