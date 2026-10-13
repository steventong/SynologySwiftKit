import XCTest
@testable import SynologySwiftKit

final class RemotePlayerApiTests: XCTestCase {
    func testListFiltersVirtualPlayersAndAllowsMissingCapabilities() async throws {
        let client = MockApiClient()
        client.mockResponse = try JSONDecoder().decode(RemotePlayerList.self, from: Data(#"{"players":[{"id":"__SYNO_WEB_PLAYER__","name":"Web","type":"stream"},{"id":"__SYNO_Multiple_AirPlay__","name":"Group","type":"airplay"},{"id":"speaker","name":"Living Room","type":"renderer","support_seek":true}]}"#.utf8))
        let devices = try await RemotePlayerApi(apiClient: client).list()
        XCTAssertEqual(devices.map(\.id), ["speaker"])
        XCTAssertEqual(devices.first?.supportsSeek, true)
        XCTAssertNil(devices.first?.passwordProtected)
    }

    func testReplacesEntireExistingQueueEscapesSongIDsAndStartsFirstSong() async throws {
        let client = MockApiClient()
        client.requestHandler = { endpoint in
            if endpoint.method == "getplaylist" { return RemotePlayerQueue(total: 12) }
            return EmptyData()
        }
        try await RemotePlayerApi(apiClient: client).playQueue(deviceID: "speaker", songIDs: ["song,a", "song_b"], library: .shared)
        let requests = client.requestedEndpoints
        XCTAssertEqual(requests.map(\.method), ["getplaylist", "updateplaylist", "control"])
        XCTAssertEqual(requests[1].parameters["limit"]?.stringValue, "12")
        XCTAssertEqual(requests[1].parameters["offset"]?.stringValue, "0")
        XCTAssertEqual(requests[1].parameters["songs"]?.stringValue, "song\\,a,song_b")
        XCTAssertEqual(requests[2].parameters["action"]?.stringValue, "play")
        XCTAssertEqual(requests[2].parameters["value"]?.stringValue, "0")
        XCTAssertTrue(requests.allSatisfy { $0.version == 3 })
    }

    func testContextChangeAfterReadPreventsQueueMutation() async throws {
        let client = MockApiClient()
        client.mockResponse = RemotePlayerQueue(total: 1)
        var validations = 0
        do {
            try await RemotePlayerApi(apiClient: client).playQueue(deviceID: "speaker", songIDs: ["song"], library: .shared) {
                validations += 1
                if validations == 3 { throw CancellationError() }
            }
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertEqual(client.requestedEndpoints.map(\.method), ["getplaylist"])
    }

    func testQueueFailureDoesNotIssuePlay() async throws {
        let client = MockApiClient()
        client.requestHandler = { endpoint in
            if endpoint.method == "getplaylist" { return RemotePlayerQueue(total: 1) }
            throw SynologyError.api(code: 502, message: "Device busy")
        }
        do {
            try await RemotePlayerApi(apiClient: client).playQueue(deviceID: "speaker", songIDs: ["song"], library: .shared)
            XCTFail("Expected device error")
        } catch {}
        XCTAssertEqual(client.requestedEndpoints.map(\.method), ["getplaylist", "updateplaylist"])
    }
}
