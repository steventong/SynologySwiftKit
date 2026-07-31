import XCTest
@testable import SynologySwiftKit

final class TransportAndReachabilityTests: XCTestCase {
    func testPingPongSingleAndAggregatedReachability() async throws {
        let apiClient = MockApiClient()
        apiClient.rawRequestHandler = { url, _, _, _, _ in
            if url.absoluteString.contains("bad-host") {
                throw SynologyError.network(message: "down")
            }
            return PingPong.PingPongResult(success: url.absoluteString.contains("ok"), ezid: nil)
        }

        let pingpong = PingPong(apiClient: apiClient, timeout: 1)

        let singleSuccess = try await pingpong.pingpong(url: "https://ok-host")
        let singleFail = try await pingpong.pingpong(url: "https://bad-host")
        let results = try await pingpong.pingpong(connections: [
            .wan: ["https://bad-host", "https://ok-host"],
            .lan: ["https://ok-host"],
        ])
        let best = try await pingpong.pingpongFirst(connections: [
            .relay: ["https://ok-host"],
            .lan: ["https://ok-host"],
        ])

        XCTAssertTrue(singleSuccess)
        XCTAssertFalse(singleFail)
        XCTAssertEqual(results[.lan], "https://ok-host")
        XCTAssertEqual(best?.type, .lan)
    }
}
