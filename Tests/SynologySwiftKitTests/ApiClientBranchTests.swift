import XCTest
@testable import SynologySwiftKit

final class ApiClientBranchTests: XCTestCase {
    func testRawRequestRejectsNon200Responses() async {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory())
        transport.handler = { request, _ in
            (
                Data("{}".utf8),
                makeHTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 500)
            )
        }

        do {
            let _: EmptyData = try await client.request(url: URL(string: "https://nas.local/raw")!)
            XCTFail("Expected non-200 to throw")
        } catch let SynologyError.network(message) {
            XCTAssertTrue(message.contains("Invalid HTTP status"))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testRawRequestMapsURLErrorVariants() async {
        let cases: [URLError.Code] = [.timedOut, .cannotFindHost, .secureConnectionFailed, .badURL]

        for code in cases {
            let transport = HTTPClientFactorySpy()
            let client = ApiClient(httpClientFactory: transport.makeFactory())
            transport.handler = { _, _ in
                throw URLError(code)
            }

            do {
                let _: EmptyData = try await client.request(url: URL(string: "https://nas.local/raw")!)
                XCTFail("Expected URLError \(code)")
            } catch let SynologyError.network(message) {
                XCTAssertFalse(message.isEmpty)
            } catch {
                XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testRequestHandlesSessionAndApiErrors() async {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory())
        client.apiInfoProvider = TestApiInfoProvider(
            nodes: [SynologyApi.AudioStation.INFO.name: ApiInfoNode(path: "AudioStation/info.cgi", minVersion: 1, maxVersion: 6, requestFormat: nil)]
        )
        client.updateConnection(type: .custom_domain, url: "https://nas.local")
        client.updateSession(sid: "sid-123", did: nil)
        transport.handler = { request, _ in
            let url = try XCTUnwrap(request.url)
            return (try makeJSONData(["success": false, "error": ["code": 105]]), makeHTTPURLResponse(url: url))
        }

        let endpoint = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", version: 6, httpMethod: .post)
        do {
            let _: AudioStationInfo = try await client.request(endpoint)
            XCTFail("Expected API permission error")
        } catch let SynologyError.api(code, _) {
            XCTAssertEqual(code, 105)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testBuildUrlSupportsCustomPathEndpoints() async throws {
        let client = ApiClient(httpClientFactory: HTTPClientFactorySpy().makeFactory())
        client.updateConnection(type: .custom_domain, url: "https://nas.local")
        let url = try await client.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.TAG_EDITOR_UI, fullPath: "/custom/path", parameters: ["action": "load"]))
        XCTAssertEqual(url.absoluteString, "https://nas.local/custom/path?action=load&api=tagEditorUI")
    }

    func testRequestDecodingFailureBecomesNetworkError() async {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory())
        client.apiInfoProvider = TestApiInfoProvider(
            nodes: [SynologyApi.AudioStation.SONG.name: ApiInfoNode(path: "AudioStation/song.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil)]
        )
        client.updateConnection(type: .custom_domain, url: "https://nas.local")
        client.updateSession(sid: "sid-123", did: nil)
        transport.handler = { request, _ in
            (Data("not-json".utf8), makeHTTPURLResponse(url: try XCTUnwrap(request.url)))
        }

        do {
            let _: SongListResult = try await client.request(ApiEndpoint(api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post))
            XCTFail("Expected decoding failure")
        } catch let SynologyError.network(message) {
            XCTAssertTrue(message.contains("Decoding failed"))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testRequestAllowsSuccessEnvelopeWithoutDataForEmptyResponses() async throws {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory())
        client.apiInfoProvider = TestApiInfoProvider(
            nodes: [SynologyApi.AudioStation.SONG.name: ApiInfoNode(path: "AudioStation/song.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil)]
        )
        client.updateConnection(type: .custom_domain, url: "https://nas.local")
        client.updateSession(sid: "sid-123", did: nil)
        transport.handler = { request, _ in
            (
                try makeJSONData(["success": true]),
                makeHTTPURLResponse(url: try XCTUnwrap(request.url))
            )
        }

        let result: EmptyData = try await client.request(
            ApiEndpoint(api: SynologyApi.AudioStation.SONG, method: "setrating", version: 2, httpMethod: .post)
        )

        XCTAssertNotNil(result)
    }
}
