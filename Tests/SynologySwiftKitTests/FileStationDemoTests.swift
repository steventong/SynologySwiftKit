import XCTest
@testable import SynologySwiftKit

final class FileStationDemoTests: XCTestCase {
    func testPlaybackURLPreservesSpecialCharactersAndRequestsSingleOriginalFile() async throws {
        let transport = MockApiClient()
        let path = "/共享/A & B/视频\"+#.MP4"
        transport.buildUrlHandler = { endpoint in
            XCTAssertEqual(endpoint.apiName, "SYNO.FileStation.Download")
            XCTAssertEqual(endpoint.method, "download")
            XCTAssertEqual(endpoint.version, 2)
            XCTAssertEqual(endpoint.sidOnQuery, true)
            XCTAssertEqual(endpoint.sidOnCookie, false)
            XCTAssertEqual(endpoint.parameters["mode"]?.stringValue, "open")
            let data = Data(try XCTUnwrap(endpoint.parameters["path"]?.stringValue).utf8)
            XCTAssertEqual(try JSONDecoder().decode([String].self, from: data), [path])
            return URL(string: "https://nas.example/video")!
        }
        let url = try await FileStationClient(apiClient: transport).playbackURL(path: path)
        XCTAssertEqual(url.host, "nas.example")
    }

    func testAuthUsesSDKSessionName() async throws {
        let transport = MockApiClient()
        transport.mockResponse = AuthResult(did: nil, isPortalPort: false, sid: "test-sid", synotoken: nil)
        let auth = AuthClient(apiClient: transport, keyChainStorage: makeKeyChainStorage(service: UUID().uuidString))
        _ = try await auth.login(username: "demo", password: "test")
        XCTAssertEqual(transport.requestedEndpoints.map { $0.parameters["session"]?.stringValue },
                       ["SynologySwiftKit"])
    }

    func testShareAndFileResponseDecodingAndPaginationRequest() async throws {
        let transport = MockApiClient()
        transport.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.apiName, "SYNO.FileStation.List")
            XCTAssertEqual(endpoint.version, 2)
            if endpoint.method == "list_share" {
                return try JSONDecoder().decode(FileStationShares.self, from: Data(#"{"total":1,"offset":0,"shares":[{"name":"共享","path":"/共享","isdir":true}]}"#.utf8))
            }
            XCTAssertEqual(endpoint.parameters["folder_path"]?.stringValue, "/共享/A & B")
            XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "200")
            XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "200")
            return try JSONDecoder().decode(FileStationPage.self, from: Data(#"{"total":201,"offset":200,"files":[{"name":"测试.txt","path":"/共享/A & B/测试.txt","isdir":false,"additional":{"size":1024,"time":{"mtime":1700000000}}}]}"#.utf8))
        }
        let files = FileStationClient(apiClient: transport)
        let shares = try await files.listShares()
        XCTAssertEqual(shares.shares.first?.path, "/共享")
        let page = try await files.list(folderPath: "/共享/A & B", offset: 200)
        XCTAssertEqual(page.files.first?.additional?.size, 1024)
        XCTAssertEqual(page.total, 201)
    }

    func testFileListingPropagatesPermissionError() async throws {
        let transport = MockApiClient()
        transport.mockError = SynologyError.api(code: 407, message: "Permission denied")
        do {
            _ = try await FileStationClient(apiClient: transport).list(folderPath: "/private")
            XCTFail("Expected an error")
        } catch let SynologyError.api(code, _) {
            XCTAssertEqual(code, 407)
        }
    }
}
