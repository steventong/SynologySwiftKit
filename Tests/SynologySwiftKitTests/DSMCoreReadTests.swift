import XCTest
@testable import SynologySwiftKit

final class DSMCoreReadTests: XCTestCase {
    func testBothAPIsUseExplicitSIDWithoutAmbientCookiesAndPreserveSessionOnRejection() async throws {
        let transport = HTTPClientFactorySpy()
        let client = makeClient(transport)
        var expired = false
        client.addInterceptor(AuthInterceptor(sessionProvider: { client.session }, onSessionExpired: {
            expired = true
            client.clearSession()
        }))
        let timeout = DesktopTimeoutClient(apiClient: client)
        let user = NormalUserClient(apiClient: client)
        for code in [105, 106, 107, 119, 102] {
            transport.handler = { request, _ in
                XCTAssertFalse(request.httpShouldHandleCookies)
                XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
                let body = String(data: try XCTUnwrap(requestBodyData(request)), encoding: .utf8)!
                let items = URLComponents(string: "https://example.test/?" + body)!.queryItems!
                XCTAssertEqual(items.filter { $0.name == "_sid" }.map(\.value), ["current-siX"])
                let api = items.first { $0.name == "api" }?.value
                XCTAssertEqual(items.first { $0.name == "method" }?.value,
                               api == "SYNO.Core.Desktop.Timeout" ? "check" : "get")
                XCTAssertEqual(items.first { $0.name == "version" }?.value, "1")
                return (try makeJSONData(["success": false, "error": ["code": code]]),
                        makeHTTPURLResponse(url: request.url!))
            }
            let results = [try await timeout.check(sid: "current-siX"), try await user.get(sid: "current-siX")]
            for result in results {
                XCTAssertFalse(result.success)
                XCTAssertEqual(result.error?.code, code)
            }
            XCTAssertFalse(expired)
            XCTAssertEqual(client.session?.sid, "current-sid")
        }
    }

    func testCurrentSessionAndSuccessWithoutDataOrWithUserFields() async throws {
        let transport = HTTPClientFactorySpy()
        let client = makeClient(transport)
        client.addInterceptor(AuthInterceptor(sessionProvider: { client.session }))
        transport.handler = { request, _ in
            let body = String(data: try XCTUnwrap(requestBodyData(request)), encoding: .utf8)!
            XCTAssertTrue(body.contains("_sid=current-sid"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            if body.contains("Desktop.Timeout") {
                return (try makeJSONData(["success": true]), makeHTTPURLResponse(url: request.url!))
            }
            return (try makeJSONData(["success": true, "data": ["username": "tester", "OTP_enable": false,
                                          "extra": ["items": [1, 2]]]]), makeHTTPURLResponse(url: request.url!))
        }
        let checked = try await DesktopTimeoutClient(apiClient: client).check()
        XCTAssertTrue(checked.success)
        XCTAssertNil(checked.data)
        let user = try await NormalUserClient(apiClient: client).get()
        XCTAssertEqual(user.data?["username"], .string("tester"))
        XCTAssertEqual(user.data?["OTP_enable"], .bool(false))
        let roundTrip = try JSONDecoder().decode(DSMReadResponse.self, from: JSONEncoder().encode(user))
        XCTAssertEqual(roundTrip.data, user.data)
    }

    func testNetworkFailureThrowsInsteadOfReportingInvalidSession() async throws {
        let transport = HTTPClientFactorySpy()
        let client = makeClient(transport)
        transport.handler = { _, _ in throw URLError(.timedOut) }
        do {
            _ = try await DesktopTimeoutClient(apiClient: client).check(sid: "current-sid")
            XCTFail("Expected network failure")
        } catch {
            XCTAssertEqual(client.session?.sid, "current-sid")
        }
    }

    func testMalformedResponseThrowsAndDoesNotLogPayload() async throws {
        let oldEnabled = Logger.isEnabled
        let oldDestination = Logger.destination
        let oldHandler = Logger.handler
        defer {
            Logger.isEnabled = oldEnabled
            Logger.destination = oldDestination
            Logger.handler = oldHandler
        }
        Logger.isEnabled = true
        Logger.destination = .handler
        Logger.handler = { record in
            XCTAssertFalse(record.message.contains("echoed-secret-sid"))
        }
        let transport = HTTPClientFactorySpy()
        let client = makeClient(transport)
        transport.handler = { request, _ in
            (Data("{invalid echoed-secret-sid".utf8), makeHTTPURLResponse(url: request.url!))
        }
        do {
            _ = try await NormalUserClient(apiClient: client).get(sid: "current-sid")
            XCTFail("Expected decoding failure")
        } catch {
            XCTAssertEqual(client.session?.sid, "current-sid")
        }
    }

    private func makeClient(_ transport: HTTPClientFactorySpy) -> ApiClient {
        let client = ApiClient(httpClientFactory: transport.makeFactory(), keyValueStorage: MockKeyValueStorage())
        client.apiInfoProvider = TestApiInfoProvider(nodes: [
            "SYNO.Core.Desktop.Timeout": ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil),
            "SYNO.Core.NormalUser": ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil)
        ])
        client.updateConnection(type: .custom_domain, url: "https://nas.local")
        client.updateSession(sid: "current-sid", did: "device")
        return client
    }
}
