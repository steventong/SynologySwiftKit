import XCTest
@testable import SynologySwiftKit

final class ApiClientHappyPathTests: XCTestCase {
    func testRequestBuildsAuthenticatedPostAndDecodesEnvelope() async throws {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory())
        client.apiInfoProvider = TestApiInfoProvider(
            nodes: [SynologyApi.AudioStation.SONG.name: ApiInfoNode(path: "AudioStation/song.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil)]
        )
        client.updateConnection(type: .custom_domain, url: "https://nas.local")
        client.updateSession(sid: "sid-123", did: "did-123")
        client.addInterceptor(AuthInterceptor(sessionProvider: { client.session }))

        transport.handler = { request, configuration in
            XCTAssertEqual(configuration.trustedSSLDomain, "nas.local")
            XCTAssertEqual(request.url?.absoluteString, "https://nas.local/webapi/AudioStation/song.cgi")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "id=sid-123; did=did-123")

            let body = String(data: try XCTUnwrap(requestBodyData(request)), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("api=SYNO.AudioStation.Song"))
            XCTAssertTrue(body.contains("method=getinfo"))
            XCTAssertTrue(body.contains("version=2"))
            XCTAssertTrue(body.contains("id=music_1"))

            let payload = try makeJSONData([
                "success": true,
                "data": [
                    "songs": [[
                        "id": "music_1",
                        "title": "Track 1",
                        "type": "file",
                        "path": "/music/Track 1.mp3",
                    ]],
                ],
            ])
            return (payload, makeHTTPURLResponse(url: try XCTUnwrap(request.url)))
        }

        let endpoint = ApiEndpoint(
            api: SynologyApi.AudioStation.SONG,
            method: "getinfo",
            version: 2,
            httpMethod: .post,
            parameters: ["id": "music_1"]
        )
        let result: SongInfo = try await client.request(endpoint)

        XCTAssertEqual(result.songs.first?.id, "music_1")
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testBuildUrlAddsSidForQueryAuthenticatedApi() async throws {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory())
        client.apiInfoProvider = TestApiInfoProvider(
            nodes: [SynologyApi.AudioStation.COVER.name: ApiInfoNode(path: "AudioStation/cover.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil)]
        )
        client.updateConnection(type: .custom_domain, url: "https://nas.local")
        client.updateSession(sid: "sid-xyz", did: nil)

        let url = try await client.buildUrl(
            ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getsongcover", version: 1) {
                ("id", "music_99")
                ("library", "shared")
            }
        )

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "nas.local")
        XCTAssertEqual(url.path, "/webapi/AudioStation/cover.cgi")
        XCTAssertURL(url, contains: [
            "api": "SYNO.AudioStation.Cover",
            "method": "getsongcover",
            "version": "1",
            "id": "music_99",
            "library": "shared",
            "_sid": "sid-xyz",
        ])
    }

    func testBuildUrlNormalizesConnectionBasePath() async throws {
        let client = ApiClient(httpClientFactory: HTTPClientFactorySpy().makeFactory())
        client.apiInfoProvider = TestApiInfoProvider(
            nodes: [SynologyApi.AudioStation.COVER.name: ApiInfoNode(path: "AudioStation/cover.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil)]
        )
        client.updateConnection(type: .custom_domain, url: "https://nas.local/dsm/")
        client.updateSession(sid: "sid-xyz", did: nil)

        let url = try await client.buildUrl(
            ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getsongcover", version: 1) {
                ("id", "music_99")
            }
        )

        XCTAssertEqual(url.absoluteString.contains("//webapi"), false)
        XCTAssertEqual(url.path, "/dsm/webapi/AudioStation/cover.cgi")
    }
}
