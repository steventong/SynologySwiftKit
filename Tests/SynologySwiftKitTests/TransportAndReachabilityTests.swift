import XCTest
import SwiftHttpClient
@testable import SynologySwiftKit

final class TransportAndReachabilityTests: XCTestCase {
    func testSwiftHttpClientAdapterMapsHTTPClientErrors() async throws {
        try await assertMappedTransportError(.invalidResponse, expectedMessage: "invalid response")
        try await assertMappedTransportError(.httpStatus(code: 418), expectedMessage: "http status: 418")
        try await assertMappedTransportError(.decodingFailed(message: "bad"), expectedMessage: "decoding failed: bad")
    }

    func testPingPongSingleAndAggregatedReachability() async {
        let apiClient = MockApiClient()
        apiClient.rawRequestHandler = { url, _, _, _, _ in
            if url.absoluteString.contains("bad-host") {
                throw SynologyError.network(message: "down")
            }
            return PingPong.PingPongResult(success: url.absoluteString.contains("ok"), ezid: nil)
        }

        let pingpong = PingPong(apiClient: apiClient, timeout: 1)

        let singleSuccess = await pingpong.pingpong(url: "https://ok-host")
        let singleFail = await pingpong.pingpong(url: "https://bad-host")
        let results = await pingpong.pingpong(connections: [
            .wan: ["https://bad-host", "https://ok-host"],
            .lan: ["https://ok-host"],
        ])
        let best = await pingpong.pingpongFirst(connections: [
            .relay: ["https://ok-host"],
            .lan: ["https://ok-host"],
        ])

        XCTAssertTrue(singleSuccess)
        XCTAssertFalse(singleFail)
        XCTAssertEqual(results[.lan], "https://ok-host")
        XCTAssertEqual(best?.type, .lan)
    }
}

private struct ThrowingSwiftHTTPClient: SwiftHTTPClientSending {
    let error: HTTPClientError

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        throw error
    }
}

private func assertMappedTransportError(_ error: HTTPClientError, expectedMessage: String, file: StaticString = #filePath, line: UInt = #line) async throws {
    let transport = SwiftHttpClientAdapter { _, _ in
        ThrowingSwiftHTTPClient(error: error)
    }

    do {
        _ = try await transport.send(URLRequest(url: URL(string: "https://nas.local")!), timeout: 1, trustedSSLDomain: nil)
        XCTFail("Expected transport error", file: file, line: line)
    } catch let SynologyError.network(message) {
        XCTAssertEqual(message, expectedMessage, file: file, line: line)
    }
}
