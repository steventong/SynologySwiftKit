import XCTest
@testable import SynologySwiftKit

final class FolderApiTests: XCTestCase {
    func testServerExpansionUsesV3AndPreservesPaginationAndMetadata() async throws {
        let client = MockApiClient()
        client.mockResponse = FolderListResult(id: "dir_42", items: [], offset: 200, total: 250, folderTotal: 0)
        let api = FolderApi(apiClient: client)
        let page = try await api.list(id: "dir_42", limit: 200, offset: 200, recursive: true)
        let endpoint = try XCTUnwrap(client.requestedEndpoints.last)
        XCTAssertEqual(endpoint.parameters["version"]?.stringValue, "3")
        XCTAssertEqual(endpoint.parameters["id"]?.stringValue, "dir_42")
        XCTAssertEqual(endpoint.parameters["recursive"]?.stringValue, "true")
        XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "200")
        XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "200")
        XCTAssertEqual(endpoint.parameters["additional"]?.stringValue, "song_tag,song_audio,song_rating")
        XCTAssertEqual(page.total, 250)
    }

    func testNormalBrowsingDoesNotExpandChildren() async throws {
        let client = MockApiClient()
        client.mockResponse = FolderListResult(id: "", items: [], offset: 0, total: 0, folderTotal: 0)
        _ = try await FolderApi(apiClient: client).list(id: nil)
        let endpoint = try XCTUnwrap(client.requestedEndpoints.last)
        XCTAssertEqual(endpoint.parameters["id"]?.stringValue, "")
        XCTAssertEqual(endpoint.parameters["recursive"]?.stringValue, "false")
    }

    func testRootReturnsOnlyFirstThousandSongsWithoutFollowingTotal() async throws {
        for rootID: String? in [nil, ""] {
            let client = MockApiClient()
            client.mockResponse = SongListResult(offset: 0, total: 50000, songs: (0..<1000).map {
                Song(id: "music_\($0)", title: "Song", type: "file", path: "/music/nested/\($0).mp3")
            })
            let page = try await FolderApi(apiClient: client).list(id: rootID, limit: 1000, recursive: true)
            XCTAssertEqual(page.items.count, 1000)
            XCTAssertEqual(page.total, 50000)
            XCTAssertEqual(page.items.last?.id, "music_999")
            XCTAssertEqual(client.requestedEndpoints.count, 1)
            let endpoint = try XCTUnwrap(client.requestedEndpoints.first)
            XCTAssertEqual(endpoint.api, SynologyApi.AudioStation.SONG)
            XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "all")
            XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "1000")
            XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "0")
        }
    }

    func testConcreteFolderReturnsOnlyFirstThousandSongsWithoutFollowingTotal() async throws {
        let client = MockApiClient()
        client.mockResponse = FolderListResult(id: "dir_a", items: (0..<1000).map {
            Folder(id: "music_\($0)", path: "/music/\($0).mp3", title: "Song", type: "file")
        }, offset: 0, total: 50000, folderTotal: 0)
        let page = try await FolderApi(apiClient: client).list(id: "dir_a", limit: 1000, recursive: true)
        XCTAssertEqual(page.items.count, 1000)
        XCTAssertEqual(page.total, 50000)
        XCTAssertEqual(client.requestedEndpoints.count, 1)
        let endpoint = try XCTUnwrap(client.requestedEndpoints.first)
        XCTAssertEqual(endpoint.api, SynologyApi.AudioStation.FOLDER)
        XCTAssertEqual(endpoint.parameters["id"]?.stringValue, "dir_a")
        XCTAssertEqual(endpoint.parameters["recursive"]?.stringValue, "true")
        XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "1000")
        XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "0")
    }

    func testRecursiveRootPropagatesFailureWithoutMoreRequests() async {
        let client = MockApiClient()
        client.mockError = URLError(.timedOut)
        do {
            _ = try await FolderApi(apiClient: client).list(id: nil, limit: 1000, recursive: true)
            XCTFail("A failed query must not return an empty list")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        XCTAssertEqual(client.requestedEndpoints.count, 1)
    }
}
