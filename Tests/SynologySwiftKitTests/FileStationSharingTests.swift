import XCTest
@testable import SynologySwiftKit

final class FileStationSharingTests: XCTestCase {
    func testCreateEncodesPathAndDateAndReturnsPublicURL() async throws {
        let transport = MockApiClient()
        let path = "/共享/旅行, + & \"海底\".mp4"
        transport.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.apiName, "SYNO.FileStation.Sharing")
            XCTAssertEqual(endpoint.version, 3)
            XCTAssertEqual(endpoint.method, "create")
            XCTAssertEqual(endpoint.httpMethod, .post)
            XCTAssertEqual(try self.stringParameter("path", endpoint), path)
            XCTAssertEqual(try self.stringParameter("date_expired", endpoint), "2026-10-25")
            XCTAssertEqual(try self.stringParameter("password", endpoint), "a+\"b")
            let data = try JSONSerialization.data(withJSONObject: ["links": [
                ["error": 0, "id": "public-id", "path": path, "url": "https://nas.example/sharing/public-id"]
            ]])
            return try JSONDecoder().decode(FileStationClient.SharingCreation.self, from: data)
        }
        let link = try await FileStationClient(apiClient: transport)
            .createSharingLink(path: path, expirationDate: "2026-10-25", password: "a+\"b")
        XCTAssertEqual(link.id, "public-id")
        XCTAssertEqual(link.url, "https://nas.example/sharing/public-id")
        XCTAssertEqual(link.dateExpired, "2026-10-25")
        XCTAssertEqual(link.hasPassword, true)
    }

    func testPermanentLinkUsesZeroAndOmitsPassword() async throws {
        let transport = MockApiClient()
        transport.requestHandler = { endpoint in
            XCTAssertEqual(try self.stringParameter("date_expired", endpoint), "0")
            XCTAssertNil(endpoint.parameters["password"])
            return try JSONDecoder().decode(FileStationClient.SharingCreation.self, from: Data(
                #"{"links":[{"error":0,"id":"a","path":"/share/a","url":"https://nas.example/sharing/a"}]}"#.utf8))
        }
        let link = try await FileStationClient(apiClient: transport).createSharingLink(path: "/share/a")
        XCTAssertEqual(link.dateExpired, "0")
    }

    func testPerItemErrorIsNotReportedAsSuccessOrRetried() async throws {
        let transport = MockApiClient()
        transport.mockResponse = try JSONDecoder().decode(FileStationClient.SharingCreation.self,
            from: Data(#"{"links":[{"error":403,"path":"/share/a"}]}"#.utf8))
        do {
            _ = try await FileStationClient(apiClient: transport).createSharingLink(path: "/share/a")
            XCTFail("Expected item failure")
        } catch let SynologyError.api(code, _) { XCTAssertEqual(code, 403) }
        XCTAssertEqual(transport.requestedEndpoints.count, 1)
    }

    func testIncompleteCreationIsRejected() async throws {
        let transport = MockApiClient()
        for json in [#"{"links":[]}"#, #"{"links":[{"error":0,"path":"/share/a"}]}"#] {
            transport.mockResponse = try JSONDecoder().decode(FileStationClient.SharingCreation.self, from: Data(json.utf8))
            do {
                _ = try await FileStationClient(apiClient: transport).createSharingLink(path: "/share/a")
                XCTFail("Expected incomplete response failure")
            } catch let SynologyError.api(code, _) { XCTAssertEqual(code, -1) }
        }
    }

    func testInvalidDatesDoNotSubmit() async throws {
        let transport = MockApiClient()
        for date in ["2026-02-30", "2026-1-1", "tomorrow", "0"] {
            do {
                _ = try await FileStationClient(apiClient: transport).createSharingLink(path: "/share/a", expirationDate: date)
                XCTFail("Expected invalid date")
            } catch let SynologyError.api(code, _) { XCTAssertEqual(code, 400) }
        }
        XCTAssertTrue(transport.requestedEndpoints.isEmpty)
    }

    func testListAndGetInfoDecodeExistingLinks() async throws {
        let transport = MockApiClient()
        let json = #"{"id":"a","path":"/share/a","url":"https://nas.example/sharing/a","status":"expired","date_expired":"2026-01-01","date_available":"0","has_password":true}"#
        transport.requestHandler = { endpoint in
            if endpoint.method == "getinfo" {
                XCTAssertEqual(try self.stringParameter("id", endpoint), "a")
                return try JSONDecoder().decode(FileStationSharingLink.self, from: Data(json.utf8))
            }
            XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "200")
            XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "100")
            XCTAssertEqual(endpoint.parameters["force_clean"]?.stringValue, "true")
            return try JSONDecoder().decode(FileStationSharingPage.self,
                from: Data("{\"offset\":200,\"total\":201,\"links\":[\(json)]}".utf8))
        }
        let client = FileStationClient(apiClient: transport)
        let page = try await client.listSharingLinks(offset: 200, limit: 100, refreshStatus: true)
        XCTAssertEqual(page.total, 201)
        XCTAssertEqual(page.links.first?.status, "expired")
        let link = try await client.sharingLink(id: "a")
        XCTAssertEqual(link.hasPassword, true)
    }

    func testDeleteUsesSharingEndpointAndPropagatesFailure() async throws {
        let transport = MockApiClient()
        transport.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.apiName, "SYNO.FileStation.Sharing")
            XCTAssertEqual(endpoint.method, "delete")
            XCTAssertEqual(endpoint.httpMethod, .post)
            XCTAssertEqual(try self.stringParameter("id", endpoint), "a\"+")
            return EmptyData()
        }
        try await FileStationClient(apiClient: transport).deleteSharingLink(id: "a\"+")
        transport.requestHandler = nil
        transport.mockError = SynologyError.api(code: 105, message: "Denied")
        do {
            try await FileStationClient(apiClient: transport).deleteSharingLink(id: "a")
            XCTFail("Expected rejection")
        } catch let SynologyError.api(code, _) { XCTAssertEqual(code, 105) }
    }

    private func stringParameter(_ name: String, _ endpoint: ApiEndpoint) throws -> String {
        try JSONDecoder().decode(String.self, from: Data(XCTUnwrap(endpoint.parameters[name]?.stringValue).utf8))
    }

    func testEditPreservesOmittedFieldsAndEncodesPassword() async throws {
        let transport = MockApiClient()
        transport.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.apiName, "SYNO.FileStation.Sharing")
            XCTAssertEqual(endpoint.method, "edit")
            XCTAssertEqual(endpoint.version, 3)
            XCTAssertEqual(endpoint.httpMethod, .post)
            XCTAssertEqual(try self.stringParameter("id", endpoint), "existing")
            XCTAssertEqual(try self.stringParameter("password", endpoint), "a+\"&b")
            XCTAssertNil(endpoint.parameters["date_expired"])
            return EmptyData()
        }
        try await FileStationClient(apiClient: transport).updateSharingLink(id: "existing", password: "a+\"&b")
    }

    func testEditCanRemovePasswordAndSetPermanentExpiration() async throws {
        let transport = MockApiClient()
        transport.requestHandler = { endpoint in
            XCTAssertEqual(try self.stringParameter("date_expired", endpoint), "0")
            XCTAssertEqual(try self.stringParameter("password", endpoint), "")
            return EmptyData()
        }
        try await FileStationClient(apiClient: transport).updateSharingLink(id: "existing", expirationDate: "0", password: "")
    }

    func testEditRejectsInvalidInputAndDoesNotRetryErrors() async throws {
        let transport = MockApiClient()
        let client = FileStationClient(apiClient: transport)
        for (date, password) in [("2026-02-30", ""), ("2026-10-20", String(repeating: "a", count: 17))] {
            do {
                try await client.updateSharingLink(id: "a", expirationDate: date, password: password)
                XCTFail("Expected validation failure")
            } catch let SynologyError.api(code, _) { XCTAssertEqual(code, 400) }
        }
        XCTAssertTrue(transport.requestedEndpoints.isEmpty)
        transport.mockError = SynologyError.api(code: 105, message: "Denied")
        do {
            try await client.updateSharingLink(id: "a", expirationDate: "2026-10-20")
            XCTFail("Expected server failure")
        } catch let SynologyError.api(code, _) { XCTAssertEqual(code, 105) }
        XCTAssertEqual(transport.requestedEndpoints.count, 1)
    }
}
