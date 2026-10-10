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

    func testRecursiveRootUsesOneNativeAllSongsRequest() async throws {
        for rootID: String? in [nil, ""] {
            let client = MockApiClient()
            client.mockResponse = SongListResult(offset: 0, total: 2, songs: [
                Song(id: "music_a", title: "A", type: "file", path: "/music/nested/a.mp3"),
                Song(id: "music_p_b", title: "B", type: "file", path: "/home/music/b.mp3")
            ])
            let songs = try await FolderApi(apiClient: client).allItems(id: rootID, recursive: true)
            XCTAssertEqual(songs.map(\.id), ["music_a", "music_p_b"])
            XCTAssertEqual(songs.map(\.path), ["/music/nested/a.mp3", "/home/music/b.mp3"])
            XCTAssertEqual(client.requestedEndpoints.count, 1)
            let endpoint = try XCTUnwrap(client.requestedEndpoints.first)
            XCTAssertEqual(endpoint.api, SynologyApi.AudioStation.SONG)
            XCTAssertEqual(endpoint.method, "list")
            XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "all")
            XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "-1")
            XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "0")
        }
    }

    func testRecursiveRootPropagatesFailureWithoutTraversal() async {
        let client = MockApiClient()
        client.mockError = URLError(.timedOut)
        do {
            _ = try await FolderApi(apiClient: client).allItems(id: nil, recursive: true)
            XCTFail("A failed query must not return an empty list")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        XCTAssertEqual(client.requestedEndpoints.count, 1)
    }

    func testConcreteFolderUsesOneNativeRecursiveRequest() async throws {
        let client = MockApiClient()
        client.mockResponse = FolderListResult(id: "dir_a", items: [item("song_a")], offset: 0, total: 1, folderTotal: 0)
        let songs = try await FolderApi(apiClient: client).allItems(id: "dir_a", recursive: true)
        XCTAssertEqual(songs.map(\.id), ["song_a"])
        XCTAssertEqual(client.requestedEndpoints.count, 1)
        let endpoint = try XCTUnwrap(client.requestedEndpoints.first)
        XCTAssertEqual(endpoint.api, SynologyApi.AudioStation.FOLDER)
        XCTAssertEqual(endpoint.parameters["id"]?.stringValue, "dir_a")
        XCTAssertEqual(endpoint.parameters["recursive"]?.stringValue, "true")
        XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "-1")
    }

    func testEmptyRootReturnsNoSongs() async throws {
        let client = MockApiClient()
        client.mockResponse = SongListResult(offset: 0, total: 0, songs: [])
        let songs = try await FolderApi(apiClient: client).allItems(id: nil, recursive: true)
        XCTAssertTrue(songs.isEmpty)
        XCTAssertEqual(client.requestedEndpoints.count, 1)
    }

    func testTruncatedUnlimitedResponseFailsInsteadOfReturningPartialSongs() async {
        let client = MockApiClient()
        client.mockResponse = FolderListResult(id: "dir_a", items: [item("song_a")], offset: 0, total: 2, folderTotal: 0)
        do {
            _ = try await FolderApi(apiClient: client).allItems(id: "dir_a", recursive: true)
            XCTFail("Incomplete song list must not be returned")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("1/2"))
        }
        XCTAssertEqual(client.requestedEndpoints.count, 1)
    }

    private func item(_ id: String, type: String = "file") -> Folder {
        Folder(id: id, path: "/\(id)", title: id, type: type)
    }
}
