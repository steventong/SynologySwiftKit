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

    func testRecursiveRootEnumeratesEveryRootAndSongPage() async throws {
        for rootID: String? in [nil, ""] {
            let client = MockApiClient()
            var requests: [String] = []
            client.requestHandler = { endpoint in
                let id = endpoint.parameters["id"]!.stringValue
                let offset = Int(endpoint.parameters["offset"]!.stringValue)!
                requests.append("\(id):\(offset)")
                XCTAssertEqual(endpoint.parameters["recursive"]?.stringValue, id.isEmpty ? "false" : "true")
                XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "1")
                let items: [Folder]
                switch id {
                case "": items = [self.item("dir_a", type: "folder"), self.item("dir_p_b", type: "folder")]
                case "dir_a": items = [self.item("song_a"), self.item("song_b")]
                case "dir_p_b": items = [self.item("song_b"), self.item("song_c")]
                default: XCTFail("Unexpected folder"); items = []
                }
                return FolderListResult(id: id, items: Array(items.dropFirst(offset).prefix(1)), offset: offset, total: items.count, folderTotal: id.isEmpty ? 2 : 0)
            }
            let songs = try await FolderApi(apiClient: client).allItems(id: rootID, recursive: true, pageSize: 1)
            XCTAssertEqual(songs.map(\.id), ["song_a", "song_b", "song_c"])
            XCTAssertEqual(requests, [":0", ":1", "dir_a:0", "dir_a:1", "dir_p_b:0", "dir_p_b:1"])
        }
    }

    func testRecursiveRootFailureDoesNotReturnPartialSongs() async {
        let client = MockApiClient()
        client.requestHandler = { endpoint in
            switch endpoint.parameters["id"]!.stringValue {
            case "": return FolderListResult(id: "", items: [self.item("dir_a", type: "folder"), self.item("dir_b", type: "folder")], offset: 0, total: 2, folderTotal: 2)
            case "dir_a": return FolderListResult(id: "dir_a", items: [self.item("song_a")], offset: 0, total: 1, folderTotal: 0)
            default: throw URLError(.timedOut)
            }
        }
        do {
            _ = try await FolderApi(apiClient: client).allItems(id: nil, recursive: true)
            XCTFail("Partial song list must not be returned")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
    }

    func testConcreteFolderUsesServerRecursionDirectly() async throws {
        let client = MockApiClient()
        client.mockResponse = FolderListResult(id: "dir_a", items: [item("song_a")], offset: 0, total: 1, folderTotal: 0)
        let songs = try await FolderApi(apiClient: client).allItems(id: "dir_a", recursive: true)
        XCTAssertEqual(songs.map(\.id), ["song_a"])
        XCTAssertEqual(client.requestedEndpoints.count, 1)
        XCTAssertEqual(client.requestedEndpoints.first?.parameters["id"]?.stringValue, "dir_a")
        XCTAssertEqual(client.requestedEndpoints.first?.parameters["recursive"]?.stringValue, "true")
    }

    func testEmptyRootReturnsNoSongs() async throws {
        let client = MockApiClient()
        client.mockResponse = FolderListResult(id: "", items: [], offset: 0, total: 0, folderTotal: 0)
        let songs = try await FolderApi(apiClient: client).allItems(id: nil, recursive: true)
        XCTAssertTrue(songs.isEmpty)
        XCTAssertEqual(client.requestedEndpoints.count, 1)
    }

    private func item(_ id: String, type: String = "file") -> Folder {
        Folder(id: id, path: "/\(id)", title: id, type: type)
    }

}
