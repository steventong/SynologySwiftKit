import XCTest
import SwiftHttpClient
@testable import SynologySwiftKit

final class CoverageClosureTests: XCTestCase {
    func testLoggerAndJsonUtilsCoverSuccessAndFailurePaths() {
        SynologySwiftKit.Logger.info("info")
        SynologySwiftKit.Logger.debug("debug")
        SynologySwiftKit.Logger.warn("warn")
        SynologySwiftKit.Logger.error("error")

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
        let keychain = KeyChainStorage(service: service)

        XCTAssertNil(keychain.getCredentials())
        XCTAssertNil(keychain.getSessionInfo())
        XCTAssertNil(keychain.getConnectionInfo())
        XCTAssertNil(keychain.getDeviceInfo())

        keychain.saveCredentials(server: "nas.local", username: "tester", password: "secret", isEnableHttps: true)
        keychain.saveSessionInfo(sid: "sid-1", did: "did-1")
        keychain.saveConnectionInfo(url: "https://nas.local", typeString: ConnectionType.lan.rawValue)
        keychain.saveDeviceInfo("device-1", "iPhone")

        XCTAssertEqual(keychain.getCredentials()?.server, "nas.local")
        XCTAssertEqual(keychain.getCredentials()?.username, "tester")
        XCTAssertEqual(keychain.getCredentials()?.password, "secret")
        XCTAssertEqual(keychain.getCredentials()?.isEnableHttps, true)
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

    func testSwiftHttpClientTransportSendsAndMapsErrors() async throws {
        let successURL = URL(string: "https://nas.local")!
        let successTransport = SwiftHttpClientTransport { timeout, trustedSSLDomain in
            XCTAssertEqual(timeout, 3)
            XCTAssertEqual(trustedSSLDomain, "nas.local")
            return StubSwiftHTTPClient(result: .success((Data("ok".utf8), makeHTTPURLResponse(url: successURL))))
        }

        let (data, response) = try await successTransport.send(URLRequest(url: successURL), timeout: 3, trustedSSLDomain: "nas.local")
        XCTAssertEqual(String(data: data, encoding: .utf8), "ok")
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

        try await assertTransportError(.invalidResponse, expectedMessage: "invalid response")
        try await assertTransportError(.httpStatus(code: 500), expectedMessage: "http status: 500")
        try await assertTransportError(.decodingFailed(message: "bad json"), expectedMessage: "decoding failed: bad json")
    }

    func testDsmInfoApiSuccessAndErrorMapping() async throws {
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
        let api = DsmInfoApi(apiClient: successClient)
        let dsmInfo = try await api.queryDsmInfo()
        XCTAssertEqual(dsmInfo.model, "DS920+")

        let synologyErrorClient = MockApiClient()
        synologyErrorClient.mockError = SynologyError.api(code: 101, message: "bad")
        do {
            _ = try await DsmInfoApi(apiClient: synologyErrorClient).queryDsmInfo()
            XCTFail("Expected synology error")
        } catch let SynologyError.api(code, _) {
            XCTAssertEqual(code, 101)
        }

        let genericErrorClient = MockApiClient()
        genericErrorClient.mockError = URLError(.timedOut)
        do {
            _ = try await DsmInfoApi(apiClient: genericErrorClient).queryDsmInfo()
            XCTFail("Expected mapped network error")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "request failed")
        }
    }

    func testAuthApiLoginMapsErrorsAndPersistsDeviceInfo() async throws {
        let service = UUID().uuidString
        let keychain = KeyChainStorage(service: service)
        let successClient = MockApiClient()
        successClient.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.parameters["account"]?.stringValue, "tester")
            XCTAssertEqual(endpoint.parameters["passwd"]?.stringValue, "secret")
            XCTAssertEqual(endpoint.parameters["enable_device_token"]?.stringValue, "yes")
            XCTAssertEqual(endpoint.parameters["otp_code"]?.stringValue, "123456")
            return AuthResult(did: "device-1", isPortalPort: false, sid: "sid-1", synotoken: nil)
        }

        let api = AuthApi(apiClient: successClient, keyChainStorage: keychain)
        let result = try await api.login(username: "tester", password: "secret", otpCode: "123456")
        XCTAssertEqual(result.sid, "sid-1")
        XCTAssertEqual(keychain.getDeviceInfo()?.0, "device-1")

        let sessionExpiredClient = MockApiClient()
        sessionExpiredClient.mockError = SynologyError.sessionExpired(code: 403, message: "otp")
        do {
            _ = try await AuthApi(apiClient: sessionExpiredClient, keyChainStorage: keychain).login(username: "tester", password: "secret")
            XCTFail("Expected auth conversion")
        } catch let SynologyError.auth(code, message) {
            XCTAssertEqual(code, 403)
            XCTAssertEqual(message, "otp")
        }

        let apiErrorClient = MockApiClient()
        apiErrorClient.mockError = SynologyError.api(code: 404, message: "bad")
        do {
            _ = try await AuthApi(apiClient: apiErrorClient, keyChainStorage: keychain).login(username: "tester", password: "secret")
            XCTFail("Expected authError conversion")
        } catch let SynologyError.auth(code, message) {
            XCTAssertEqual(code, 404)
            XCTAssertEqual(message, Localization.text("AUTHENTICATION_CODE_FAILED"))
        }

        let genericErrorClient = MockApiClient()
        genericErrorClient.mockError = URLError(.cannotConnectToHost)
        do {
            _ = try await AuthApi(apiClient: genericErrorClient, keyChainStorage: keychain).login(username: "tester", password: "secret")
            XCTFail("Expected fallback auth error")
        } catch let SynologyError.auth(code, message) {
            XCTAssertEqual(code, -1)
            XCTAssertTrue(message.contains("login failed"))
        }
    }

    func testSynologyClientCoversSessionConnectionAndInterceptorPaths() async throws {
        let service = UUID().uuidString
        let keychain = KeyChainStorage(service: service)
        let transport = MockHTTPTransport()
        let apiClient = ApiClient(httpTransport: transport)
        let client = SynologyClient(
            config: .default,
            keyValueStorage: MockKeyValueStorage(),
            keyChainStorage: keychain,
            apiClient: apiClient
        )

        XCTAssertNil(client.getConnection())
        XCTAssertFalse(client.hasValidSession())

        client.apiClient.updateConnection(type: .lan, url: "https://nas.local")
        XCTAssertEqual(client.getConnection()?.type, .lan)

        client.updateSession(sid: "sid-1", did: "did-1")
        XCTAssertTrue(client.hasValidSession())
        XCTAssertEqual(client.getSession()?.did, "did-1")

        let testInterceptor = HeaderAppendingInterceptor()
        client.addInterceptor(testInterceptor)

        transport.handler = { request, _, _ in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test"), "1")
            let payload = try JSONEncoder().encode(SimplePayload(ok: true))
            return (payload, makeHTTPURLResponse(url: request.url!))
        }

        let payload: SimplePayload = try await client.apiClient.request(url: URL(string: "https://nas.local/raw")!)
        XCTAssertTrue(payload.ok)
    }

    func testCheckConnectionStatusCoversRefreshAndFailureBranches() async {
        let successClient = MockApiClient()
        let successKeychain = KeyChainStorage(service: UUID().uuidString)
        successKeychain.saveCredentials(server: "nas.local", username: "tester", password: "secret", isEnableHttps: true)

        let successChecker = CheckDeviceConnection(
            apiClient: successClient,
            apiInfoApi: TestApiInfoProvider(),
            quickConnectApi: QuickConnectApi(apiClient: successClient, pingpong: TestPingPong()),
            audioStationApi: AudioStationApi(apiClient: successClient),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: successKeychain
        )

        var successEvents: [CheckDeviceConnectionProgress] = []
        for await progress in successChecker.checkConnectionStatus(server: "nas.local", isHttps: true) {
            successEvents.append(progress)
        }

        guard case let .success(type, url, cached)? = successEvents.last else {
            return XCTFail("Expected refreshed success")
        }
        XCTAssertEqual(type, .custom_domain)
        XCTAssertEqual(url, "nas.local")
        XCTAssertFalse(cached)

        let failureClient = MockApiClient()
        let failureKeychain = KeyChainStorage(service: UUID().uuidString)
        failureKeychain.saveCredentials(server: "QC123456", username: "tester", password: "secret", isEnableHttps: true)
        failureClient.rawRequestHandler = { _, _, _, _, _ in
            throw SynologyError.network(message: "qc failed")
        }

        let failureChecker = CheckDeviceConnection(
            apiClient: failureClient,
            apiInfoApi: TestApiInfoProvider(),
            quickConnectApi: QuickConnectApi(apiClient: failureClient, pingpong: TestPingPong()),
            audioStationApi: AudioStationApi(apiClient: failureClient),
            pingpong: TestPingPong(singleURLReachable: false),
            keyChainStorage: failureKeychain
        )

        var failureEvents: [CheckDeviceConnectionProgress] = []
        for await progress in failureChecker.checkConnectionStatus() {
            failureEvents.append(progress)
        }

        guard case let .failed(message)? = failureEvents.last else {
            return XCTFail("Expected failure event")
        }
        XCTAssertTrue(message.contains("qc failed"))
    }

    func testSynologyUserLoginCoversCredentialRemovalAndErrorBranches() async {
        let removeKeychain = KeyChainStorage(service: UUID().uuidString)
        removeKeychain.saveCredentials(server: "nas.local", username: "tester", password: "old", isEnableHttps: true)
        let removeClient = MockApiClient()
        removeClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.AUTH.name {
                return AuthResult(did: "device-1", isPortalPort: false, sid: "sid-1", synotoken: nil)
            }
            throw SynologyError.network(message: "Unexpected endpoint")
        }

        let removeLogin = SynologyUserLogin(
            apiInfoApi: TestApiInfoProvider(),
            apiClient: removeClient,
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: removeKeychain
        )

        var removeEvents: [SynologyUserLoginProgress] = []
        for await progress in await removeLogin.login(server: "nas.local", enableHttps: true, username: "tester", password: "secret", shouldSavePassword: false) {
            removeEvents.append(progress)
        }
        guard case .completed = removeEvents.last else {
            return XCTFail("Expected completed login")
        }
        XCTAssertNil(removeKeychain.getCredentials())

        let otpKeychain = KeyChainStorage(service: UUID().uuidString)
        let otpClient = MockApiClient()
        otpClient.requestHandler = { endpoint in
            if endpoint.apiName == SynologyApi.Core.AUTH.name {
                throw SynologyError.auth(code: 403, message: "otp required")
            }
            throw SynologyError.network(message: "Unexpected endpoint")
        }

        let otpLogin = SynologyUserLogin(
            apiInfoApi: TestApiInfoProvider(),
            apiClient: otpClient,
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: otpKeychain
        )

        var otpEvents: [SynologyUserLoginProgress] = []
        for await progress in await otpLogin.login(server: "nas.local", enableHttps: true, username: "tester", password: "secret") {
            otpEvents.append(progress)
        }
        guard case .otpRequired? = otpEvents.last else {
            return XCTFail("Expected otpRequired")
        }

        let missingLogin = SynologyUserLogin(
            apiInfoApi: TestApiInfoProvider(),
            apiClient: MockApiClient(),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: KeyChainStorage(service: UUID().uuidString)
        )

        var missingEvents: [SynologyUserLoginProgress] = []
        for await progress in await missingLogin.login() {
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

            func checkSynologyApiInfo(cacheEnabled: Bool?, updateCache: Bool?) async throws -> Bool {
                throw SynologyError.network(message: "api info failed")
            }
        }

        let failureLogin = SynologyUserLogin(
            apiInfoApi: FailingApiInfoProvider(),
            apiClient: MockApiClient(),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: KeyChainStorage(service: UUID().uuidString)
        )

        var failureEvents: [SynologyUserLoginProgress] = []
        for await progress in await failureLogin.login(server: "nas.local", enableHttps: true, username: "tester", password: "secret") {
            failureEvents.append(progress)
        }
        guard case let .failed(message)? = failureEvents.last else {
            return XCTFail("Expected failed event")
        }
        XCTAssertTrue(message.contains("api info failed"))
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

private struct StubSwiftHTTPClient: SwiftHTTPClientSending {
    let result: Result<(Data, URLResponse), Error>

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try result.get()
    }
}

private struct HeaderAppendingInterceptor: RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: ApiEndpoint) async throws -> URLRequest {
        var request = request
        request.setValue("1", forHTTPHeaderField: "X-Test")
        return request
    }

    func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint) async throws -> Result<(Data, URLResponse), Error> {
        result
    }
}

private struct SimplePayload: Codable {
    let ok: Bool
}

private func assertTransportError(_ clientError: SwiftHttpClient.HTTPClientError, expectedMessage: String, file: StaticString = #filePath, line: UInt = #line) async throws {
    let transport = SwiftHttpClientTransport { _, _ in
        StubSwiftHTTPClient(result: .failure(clientError))
    }

    do {
        _ = try await transport.send(URLRequest(url: URL(string: "https://nas.local")!), timeout: 1, trustedSSLDomain: nil)
        XCTFail("Expected transport error", file: file, line: line)
    } catch let SynologyError.network(message) {
        XCTAssertEqual(message, expectedMessage, file: file, line: line)
    }
}
