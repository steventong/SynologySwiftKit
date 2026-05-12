import XCTest
@testable import SynologySwiftKit

final class AuthInterceptorTests: XCTestCase {
    func testAdaptAddsSidToGetQueryWhenRequired() async throws {
        let interceptor = AuthInterceptor(sessionProvider: { (sid: "sid-123", did: "device-1") })
        let endpoint = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", sidOnQuery: true)
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/webapi/entry.cgi?method=getinfo")))

        let adapted = try await interceptor.adapt(request, for: endpoint)
        let url = try XCTUnwrap(adapted.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "_sid", value: "sid-123")) == true)
    }

    func testAdaptAddsCookieWhenRequired() async throws {
        let interceptor = AuthInterceptor(sessionProvider: { (sid: "sid-123", did: "device-1") })
        let endpoint = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", sidOnCookie: true)
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/webapi/entry.cgi")))

        let adapted = try await interceptor.adapt(request, for: endpoint)

        XCTAssertEqual(adapted.value(forHTTPHeaderField: "Cookie"), "id=sid-123; did=device-1")
    }

    func testAdaptThrowsWhenSessionIsMissing() async {
        let interceptor = AuthInterceptor(sessionProvider: { nil })
        let endpoint = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", sidOnQuery: true)
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await interceptor.adapt(request, for: endpoint)
            XCTFail("Expected missing session to throw")
        } catch let error as SynologyError {
            guard case .sessionExpired = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
