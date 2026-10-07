import XCTest
@testable import SynologySwiftKit

final class DomainLoginDiscoveryTests: XCTestCase {
    func testFirstDomainLoginOnlyDiscoversAPIsAndAuthenticates() async {
        let transport = HTTPClientFactorySpy()
        var calls: [String] = []
        transport.handler = { request, _ in
            let url = request.url!
            calls.append(url.path)
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.port, 5001)
            return try self.response(for: request)
        }
        let client = makeClient(transport)
        let events = await login(client, server: "nas.local")
        guard case .completed = events.last else { return XCTFail("Expected login success") }
        XCTAssertEqual(calls, ["/webapi/query.cgi", "/webapi/entry.cgi"])
        XCTAssertEqual(client.session.current?.sid, "new-sid")
    }

    func testAutomaticProtocolSelectionUsesDiscoveryBeforeSendingPassword() async {
        let transport = HTTPClientFactorySpy()
        var calls: [String] = []
        transport.handler = { request, _ in
            let url = request.url!
            calls.append("\(url.scheme!)|\(url.path)")
            if url.scheme == "https" { throw URLError(.cannotConnectToHost) }
            XCTAssertEqual(url.port, 5000)
            return try self.response(for: request)
        }
        let events = await login(makeClient(transport), server: "nas.local")
        guard case .completed = events.last else { return XCTFail("Expected HTTP candidate success") }
        XCTAssertEqual(calls, ["https|/webapi/query.cgi", "http|/webapi/query.cgi", "http|/webapi/entry.cgi"])
    }

    func testExplicitHTTPSFailureDoesNotTryHTTPOrSendCredentials() async {
        let transport = HTTPClientFactorySpy()
        var calls: [URL] = []
        transport.handler = { request, _ in
            calls.append(request.url!)
            throw URLError(.cannotConnectToHost)
        }
        let events = await login(makeClient(transport), server: "https://nas.local:8443")
        guard case .failed = events.last else { return XCTFail("Expected failure") }
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.scheme, "https")
        XCTAssertEqual(calls.first?.port, 8443)
        XCTAssertEqual(calls.first?.path, "/webapi/query.cgi")
    }

    func testCertificateFailureStopsDiscoveryAndRestoresPreviousConnection() async {
        let certificate = SynologyServerCertificate(host: "nas.local", subject: "DSM", sha256Fingerprint: "AA:BB")
        let events = await failedDiscovery(SynologyError.serverCertificateUntrusted(certificate))
        guard case let .serverCertificateUntrusted(actual) = events.last else { return XCTFail("Expected certificate prompt") }
        XCTAssertEqual(actual, certificate)
    }

    func testCancellationStopsDiscoveryWithoutAuthentication() async {
        let events = await failedDiscovery(CancellationError())
        XCTAssertEqual(events.count, 1)
        guard case .connecting = events.first else { return XCTFail("Expected no failure or login event after cancellation") }
    }

    private func failedDiscovery(_ error: Error) async -> [SynologyUserLoginProgress] {
        let api = MockApiClient()
        api.connection = (.custom_domain, "https://previous.local")
        let provider = FailingDiscovery(api: api, error: error)
        let storage = makeKeyChainStorage(service: UUID().uuidString)
        let flow = SynologyUserLogin(
            apiInfoApi: provider, apiClient: api,
            authApi: AuthClient(apiClient: api, keyChainStorage: storage),
            dsmInfoApi: DSMInfoClient(apiClient: api),
            connectionChecker: ConnectionChecker(apiClient: api,
                quickConnectApi: QuickConnectClient(apiClient: api, pingpong: TestPingPong()),
                pingpong: TestPingPong(), keyChainStorage: storage),
            keyChainStorage: storage
        )
        var events: [SynologyUserLoginProgress] = []
        for await event in flow.login(server: "nas.local", username: "tester", password: "secret") { events.append(event) }
        XCTAssertEqual(provider.addresses, ["https://nas.local:5001"])
        XCTAssertTrue(api.requestedEndpoints.isEmpty)
        XCTAssertEqual(api.connection?.url, "https://previous.local")
        return events
    }

    func testRejectedPasswordDoesNotRestartDiscoveryOrTryAnotherProtocol() async {
        let transport = HTTPClientFactorySpy()
        var calls: [String] = []
        transport.handler = { request, _ in
            calls.append(request.url!.path)
            if request.url!.path == "/webapi/entry.cgi" {
                return (try makeJSONData(["success": false, "error": ["code": 400]]), makeHTTPURLResponse(url: request.url!))
            }
            return try self.response(for: request)
        }
        let events = await login(makeClient(transport), server: "nas.local")
        guard case .failed = events.last else { return XCTFail("Expected rejected login") }
        XCTAssertEqual(calls, ["/webapi/query.cgi", "/webapi/entry.cgi"])
    }

    private func makeClient(_ transport: HTTPClientFactorySpy) -> SynologyClient {
        SynologyClient(keyValueStorage: MockKeyValueStorage(), keyChainStorage: makeKeyChainStorage(service: UUID().uuidString),
                       httpClientFactory: transport.makeFactory())
    }

    private func login(_ client: SynologyClient, server: String) async -> [SynologyUserLoginProgress] {
        var events: [SynologyUserLoginProgress] = []
        for await event in client.flows.userLogin.login(server: server, username: "tester", password: "secret") {
            events.append(event)
        }
        return events
    }

    private func response(for request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        if url.path == "/webapi/query.cgi" {
            XCTAssertFalse(url.absoluteString.contains("secret"))
            XCTAssertNil(request.httpBody)
            return (try makeJSONData(["success": true, "data": [
                "SYNO.API.Auth": ["path": "entry.cgi", "minVersion": 3, "maxVersion": 7]
            ]]), makeHTTPURLResponse(url: url))
        }
        XCTAssertEqual(url.path, "/webapi/entry.cgi")
        let body = String(decoding: try XCTUnwrap(requestBodyData(request)), as: UTF8.self)
        XCTAssertTrue(body.contains("method=login"))
        XCTAssertTrue(body.contains("account=tester"))
        return (try makeJSONData(["success": true, "data": ["sid": "new-sid", "is_portal_port": false]]), makeHTTPURLResponse(url: url))
    }
}

private final class FailingDiscovery: ApiInfoProviding {
    var serverIdentity: String? { nil }
    func selectServer(_ server: String?) {}
    let api: MockApiClient
    let error: Error
    var addresses: [String] = []
    init(api: MockApiClient, error: Error) { self.api = api; self.error = error }
    func refresh() async throws {
        addresses.append(api.connection!.url)
        throw error
    }
    func loadFromCacheOrRefresh() async throws { try await refresh() }
    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode { throw error }
}
