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
}
