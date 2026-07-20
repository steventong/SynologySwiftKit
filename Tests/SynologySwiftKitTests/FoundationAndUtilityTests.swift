import XCTest
@testable import SynologySwiftKit

final class FoundationAndUtilityTests: XCTestCase {
    func testUrlUtilsAndDictionaryEncoding() {
        let encoded = UrlUtils.urlEncode("a b&c")
        XCTAssertTrue(encoded.contains("a"))

        let apiDict: [String: ApiParameterValue] = ["title": .string("Hello World"), "count": .int(2)]
        XCTAssertTrue(apiDict.urlEncodedString.contains("count=2"))
        XCTAssertNotNil(apiDict.urlEncodedData)
    }

    func testJsonUtilsAndLyricsResultDecoding() throws {
        let update = TagEditorUpdate(
            files: [],
            title: "Track",
            artist: "Artist",
            album: "Album",
            albumArtist: "Artist",
            composer: "Composer",
            genre: "Pop",
            lyrics: "lyric",
            track: 1,
            disc: 1,
            year: 2024
        )
        XCTAssertNotNil(JsonUtils.toJson(codable: [TagEditorRequest(update: update)]))

        let stringData = try makeJSONData(["lyrics": "plain lyrics"])
        let objectData = try makeJSONData(["lyrics": ["lyrics": "nested lyrics"]])
        let emptyData = try makeJSONData(["lyrics": NSNull()])

        XCTAssertEqual(try JSONDecoder().decode(LyricsResult.self, from: stringData).lyrics?.lyrics, "plain lyrics")
        XCTAssertEqual(try JSONDecoder().decode(LyricsResult.self, from: objectData).lyrics?.lyrics, "nested lyrics")
        XCTAssertNil(try JSONDecoder().decode(LyricsResult.self, from: emptyData).lyrics)
    }

    func testConnectionTypeHelpersAndHttpTypeScheme() {
        XCTAssertEqual(ConnectionType.getByName(name: "lan"), .lan)
        XCTAssertNil(ConnectionType.getByName(name: "missing"))
        XCTAssertEqual(ConnectionType.lan.name, "lan")
        XCTAssertEqual(ConnectionType.ordered.first, .lan)
        XCTAssertEqual(ConnectionType.ordered.last, .custom_domain)
        XCTAssertEqual(HttpType.HTTPS.httpScheme, "https://")
        XCTAssertEqual(HttpType.HTTP.httpScheme, "http://")
    }

    func testKeyValueStorageSupportsPrimitiveAndCodableValues() {
        let storage = MockKeyValueStorage()
        storage.setString("value", forKey: "string")
        storage.setInteger(3, forKey: "int")
        storage.setBool(true, forKey: "bool")
        storage.setDate(Date(timeIntervalSince1970: 10), forKey: "date")
        storage.setCodable(makeAudioStationInfo(), forKey: "info")

        XCTAssertEqual(storage.string(forKey: "string"), "value")
        XCTAssertEqual(storage.integer(forKey: "int"), 3)
        XCTAssertEqual(storage.bool(forKey: "bool"), true)
        XCTAssertNotNil(storage.date(forKey: "date"))
        let storedInfo: AudioStationInfo? = storage.codable(forKey: "info")
        XCTAssertEqual(storedInfo?.version, makeAudioStationInfo().version)
    }

    func testSynologyErrorsAndApiResponseMapping() throws {
        XCTAssertEqual(SynologyError.authMessage(forCode: 403), Localization.text("AUTHENTICATION_CODE_REQUIRED"))

        let expired = SynologyApiError(code: 106)
        let apiNotFound = SynologyApiError(code: 102)
        let unknown = SynologyApiError.unknown

        guard case .sessionExpired(106, _) = expired.toSynologyError() else {
            return XCTFail("Expected sessionExpired")
        }
        guard case .api(102, _) = apiNotFound.toSynologyError() else {
            return XCTFail("Expected api error")
        }
        XCTAssertEqual(unknown.code, -1)

        let success = SynologyResponse(success: true, error: nil, data: "ok")
        XCTAssertEqual(try success.unwrap(), "ok")

        do {
            _ = try SynologyResponse<String>(success: false, error: SynologyApiError(code: 105), data: nil).unwrap()
            XCTFail("Expected unwrap to throw")
        } catch let SynologyError.sessionExpired(code, _) {
            XCTAssertEqual(code, 105)
        }
    }

    func testSynologyApiErrorDecodesBothErrorsShapes() throws {
        // 常规错误：errors 为子错误码数组 / Regular error: errors is an array of sub-codes
        let arrayForm = Data(#"{"success":false,"error":{"code":1002,"errors":[1006]}}"#.utf8)
        let arrayResponse = try JSONDecoder().decode(SynologyResponse<EmptyData>.self, from: arrayForm)
        XCTAssertEqual(arrayResponse.error?.code, 1002)
        XCTAssertEqual(arrayResponse.error?.errors, [1006])

        // 2FA 错误：errors 为字典 {token, types} / 2FA error: errors is a dictionary {token, types}
        let dictForm = Data(#"{"success":false,"error":{"code":403,"errors":{"token":"jwt","types":[{"type":"otp"}]}}}"#.utf8)
        let dictResponse = try JSONDecoder().decode(SynologyResponse<EmptyData>.self, from: dictForm)
        XCTAssertEqual(dictResponse.error?.code, 403)
        XCTAssertEqual(dictResponse.error?.errors, [])
        guard case .auth(403, _)? = dictResponse.error?.toSynologyError() else {
            return XCTFail("Expected auth error for code 403")
        }
    }

    func testApiEndpointAndParametersBuilder() {
        let endpoint = ApiEndpoint(api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post) {
            ("limit", 10)
            ("keyword", "hello")
            if true {
                ("offset", 0)
            }
            for pair in [("library", "shared"), ("additional", "song_tag")] {
                pair
            }
        }

        XCTAssertEqual(endpoint.apiName, SynologyApi.AudioStation.SONG.name)
        XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "10")
        XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "shared")
        XCTAssertEqual(ApiEndpoint.post(api: SynologyApi.AudioStation.SEARCH, method: "list").httpMethod, .post)
        XCTAssertTrue(ApiEndpoint.custom(api: SynologyApi.AudioStation.TAG_EDITOR_UI, path: "/tag").isCustomPath)
        let floatLiteralValue: ApiParameterValue = 1.5
        XCTAssertEqual(floatLiteralValue.stringValue, "1.5")

        let arrayValue: ApiParameterValue = ["music_1", "music_2"]
        XCTAssertEqual(arrayValue.stringValue, "music_1,music_2")

        struct Payload: Encodable {
            let id: String
        }
        let jsonValue = try? ApiParameterValue.jsonEncoded(Payload(id: "music_1"))
        XCTAssertEqual(jsonValue?.stringValue, #"{"id":"music_1"}"#)
    }

    func testAuthInterceptorInjectsSidAndCookieAndClearsExpiredSession() async throws {
        var didExpire = false
        let interceptor = AuthInterceptor(
            sessionProvider: { ("sid-123", "did-123") },
            onSessionExpired: { didExpire = true }
        )

        var getRequest = URLRequest(url: URL(string: "https://nas.local/path?foo=bar")!)
        getRequest.httpMethod = "GET"
        let getEndpoint = ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "cover", sidOnQuery: true)
        let adaptedGet = try await interceptor.adapt(getRequest, for: getEndpoint)
        XCTAssertTrue(adaptedGet.url?.absoluteString.contains("_sid=sid-123") == true)

        var postRequest = URLRequest(url: URL(string: "https://nas.local/path")!)
        postRequest.httpMethod = "POST"
        postRequest.httpBody = "foo=bar".data(using: .utf8)
        let postEndpoint = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", httpMethod: .post, sidOnCookie: true)
        let adaptedPost = try await interceptor.adapt(postRequest, for: postEndpoint)
        XCTAssertEqual(adaptedPost.value(forHTTPHeaderField: "Cookie"), "id=sid-123; did=did-123")

        _ = try await interceptor.process(.failure(SynologyError.sessionExpired(code: 105, message: "expired")), for: postEndpoint)
        XCTAssertTrue(didExpire)
    }

    func testRequestInterceptorDefaultsAndRequestContext() async throws {
        struct DummyInterceptor: RequestInterceptorWithContext {}

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let endpoint = ApiEndpoint(api: SynologyApi.Core.INFO, method: "query")
        var context = RequestContext(metadata: ["trace": "1"])
        let interceptor = DummyInterceptor()

        let adapted = try await interceptor.adapt(request, for: endpoint, context: &context)
        let processed = try await interceptor.process(.success((Data(), URLResponse())), for: endpoint, context: &context)

        XCTAssertEqual(adapted.url, request.url)
        XCTAssertEqual(context.metadata["trace"], "1")
        guard case .success = processed else {
            return XCTFail("Expected default process success passthrough")
        }
    }
}
