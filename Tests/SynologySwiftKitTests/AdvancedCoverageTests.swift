import XCTest
@testable import SynologySwiftKit

final class AdvancedCoverageTests: XCTestCase {
    func testQuickConnectUsesCachedServerAndFallsBackToRelayTunnel() async throws {
        let transport = HTTPClientFactorySpy()
        let apiClient = ApiClient(httpClientFactory: transport.makeFactory())
        let storage = MockKeyValueStorage()
        storage.setString("cached.quickconnect.to", forKey: KeyValueStorageKeys.SYNOLOGY_SERVER_URL("demoqc").keyName)

        let quickConnectApi = QuickConnectClient(
            apiClient: apiClient,
            pingpong: TestPingPong(
                firstResult: SynologyConnection(
                    type: .relay,
                    url: "https://relay.quickconnect.to:443"
                ),
                singleURLReachable: true
            ),
            timeout: 2,
            keyValueStorage: storage
        )

        transport.handler = { request, _ in
            let url = try XCTUnwrap(request.url)
            let body = String(data: try XCTUnwrap(requestBodyData(request)), encoding: .utf8) ?? ""
            XCTAssertEqual(url.host, "cached.quickconnect.to")

            if body.contains("\"command\":\"get_server_info\"") {
                return (
                    try makeJSONData([
                        "command": "get_server_info",
                        "version": 1,
                        "errno": 0,
                        "server": [
                            "interface": [["ip": "192.168.1.2"]],
                            "external": ["ip": "8.8.8.8"],
                        ],
                        "service": [
                            "port": 5000,
                            "ext_port": 5001,
                        ],
                    ]),
                    makeHTTPURLResponse(url: url)
                )
            }

            return (
                try makeJSONData([
                    "command": "request_tunnel",
                    "version": 1,
                    "errno": 0,
                    "service": [
                        "relay_dn": "relay.quickconnect.to",
                        "relay_port": 443,
                    ],
                ]),
                makeHTTPURLResponse(url: url)
            )
        }

        let connection = try await quickConnectApi.getDeviceConnection(quickConnectId: "demoqc", usesHTTPS: true)

        XCTAssertEqual(connection.type, .relay)
        XCTAssertEqual(connection.url, "https://relay.quickconnect.to:443")
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testQuickConnectThrowsWhenServerInfoCannotBeResolved() async {
        let transport = HTTPClientFactorySpy()
        let apiClient = ApiClient(httpClientFactory: transport.makeFactory())
        let quickConnectApi = QuickConnectClient(
            apiClient: apiClient,
            pingpong: TestPingPong(firstResult: nil),
            timeout: 2,
            keyValueStorage: MockKeyValueStorage()
        )

        transport.handler = { request, _ in
            (
                try makeJSONData([
                    "command": "get_server_info",
                    "version": 1,
                    "errno": 4,
                    "sites": [],
                ]),
                makeHTTPURLResponse(url: try XCTUnwrap(request.url))
            )
        }

        do {
            _ = try await quickConnectApi.getDeviceConnection(quickConnectId: "demoqc", usesHTTPS: true)
            XCTFail("Expected QuickConnect failure")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "QuickConnect server info not available")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testApiClientCoversMissingStateGetRequestsAndBusinessErrors() async throws {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory())

        do {
            _ = try await client.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo"))
            XCTFail("Expected missing apiInfoProvider")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "Host not configured")
        }

        client.apiInfoProvider = TestApiInfoProvider(
            nodes: [SynologyApi.AudioStation.SEARCH.name: ApiInfoNode(path: "AudioStation/search.cgi", minVersion: 1, maxVersion: 2, requestFormat: nil)]
        )

        do {
            let _: EmptyData = try await client.request(
                ApiEndpoint(api: SynologyApi.AudioStation.SEARCH, method: "list", version: 1, sidOnQuery: false, sidOnCookie: false)
            )
            XCTFail("Expected missing connection")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "Host not configured")
        }

        client.updateConnection(type: .custom_domain, url: "https://nas.local")
        transport.handler = { request, configuration in
            XCTAssertEqual(
                configuration.serverTrustPolicy,
                .userApprovedCertificate(host: "nas.local", sha256Fingerprint: nil)
            )
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertURL(try XCTUnwrap(request.url), contains: [
                "api": SynologyApi.AudioStation.SEARCH.name,
                "method": "list",
                "version": "2",
                "keyword": "五月天",
            ])
            return (
                try makeJSONData(["success": false, "error": ["code": 120]]),
                makeHTTPURLResponse(url: try XCTUnwrap(request.url))
            )
        }

        do {
            let _: SearchResult = try await client.request(
                ApiEndpoint(api: SynologyApi.AudioStation.SEARCH, method: "list", version: 99, httpMethod: .get, parameters: ["keyword": ApiParameterValue.string("五月天")], sidOnQuery: false, sidOnCookie: false)
            )
            XCTFail("Expected mapped business error")
        } catch let SynologyError.api(code, message) {
            XCTAssertEqual(code, 120)
            XCTAssertEqual(message, "Preserve for other purpose.")
        }
    }

    func testApiClientCoversExplicitCookieAndInterceptorFailure() async {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory())
        client.apiInfoProvider = TestApiInfoProvider(
            nodes: [SynologyApi.AudioStation.INFO.name: ApiInfoNode(path: "AudioStation/info.cgi", minVersion: 1, maxVersion: 6, requestFormat: nil)]
        )
        client.updateConnection(type: .lan, url: "http://nas.local")

        let interceptor = FailingResponseInterceptor()
        client.addInterceptor(interceptor)

        transport.handler = { request, configuration in
            XCTAssertEqual(configuration.serverTrustPolicy, .system)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "id=sid-1; did=did-1")
                return (
                    try makeSynologyEnvelope(makeAudioStationInfo()),
                    makeHTTPURLResponse(url: try XCTUnwrap(request.url))
                )
        }

        do {
            let _: AudioStationInfo = try await client.request(
                ApiEndpoint(
                    api: SynologyApi.AudioStation.INFO,
                    method: "getinfo",
                    version: 6,
                    httpMethod: .post,
                    parameters: ["sid": ApiParameterValue.string("sid-1"), "did": ApiParameterValue.string("did-1")],
                    sidOnCookie: false
                )
            )
            XCTFail("Expected interceptor failure")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "interceptor failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuthInterceptorCoversAdditionalBranches() async throws {
        let interceptor = AuthInterceptor(
            sessionProvider: { ("sid-123", "") },
            onSessionExpired: nil
        )

        var plainGet = URLRequest(url: URL(string: "https://nas.local/plain")!)
        plainGet.httpMethod = "GET"
        let noAuthEndpoint = ApiEndpoint(api: SynologyApi.Core.INFO, method: "query", sidOnQuery: false, sidOnCookie: false)
        let passthrough = try await interceptor.adapt(plainGet, for: noAuthEndpoint)
        XCTAssertEqual(passthrough.url, plainGet.url)

        var cookieRequest = URLRequest(url: URL(string: "https://nas.local/webapi")!)
        cookieRequest.httpMethod = "POST"
        let cookieEndpoint = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", httpMethod: .post, sidOnCookie: true)
        let adaptedCookie = try await interceptor.adapt(cookieRequest, for: cookieEndpoint)
        XCTAssertEqual(adaptedCookie.value(forHTTPHeaderField: "Cookie"), "id=sid-123")

        var callbackCount = 0
        let callbackInterceptor = AuthInterceptor(sessionProvider: { ("sid", nil) }, onSessionExpired: { callbackCount += 1 })
        _ = try await callbackInterceptor.process(.failure(SynologyError.sessionExpired(code: 119, message: "expired")), for: cookieEndpoint)
        _ = try await callbackInterceptor.process(.failure(SynologyError.sessionExpired(code: 999, message: "other")), for: cookieEndpoint)
        _ = try await callbackInterceptor.process(.failure(URLError(.timedOut)), for: cookieEndpoint)
        XCTAssertEqual(callbackCount, 1)
    }
}

private struct FailingResponseInterceptor: RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: ApiEndpoint) async throws -> URLRequest {
        request
    }

    func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint) async throws -> Result<(Data, URLResponse), Error> {
        .failure(SynologyError.network(message: "interceptor failed"))
    }
}
