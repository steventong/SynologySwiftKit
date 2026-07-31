import Foundation
import SwiftHttpClient
import XCTest
@testable import SynologySwiftKit

final class HTTPClientFactorySpy: @unchecked Sendable {
    struct Configuration: Equatable {
        let timeout: TimeInterval
        let trustedSSLDomain: String?
    }

    var handler: ((URLRequest, Configuration) throws -> (Data, URLResponse))?
    private let lock = NSLock()
    private(set) var requests: [URLRequest] = []
    private(set) var configurations: [Configuration] = []

    func makeFactory() -> SynologyHTTPClientFactory {
        { [self] timeout, trustedSSLDomain in
            let configuration = Configuration(timeout: timeout, trustedSSLDomain: trustedSSLDomain)
            recordConfiguration(configuration)

            StubURLProtocol.handler = { [self] request in
                recordRequest(request)
                guard let handler else {
                    throw SynologyError.network(message: "No HTTP transport handler configured")
                }
                return try handler(request, configuration)
            }

            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.protocolClasses = [StubURLProtocol.self]
            let session = URLSession(configuration: sessionConfiguration)
            return HTTPClient(session: session)
        }
    }

    private func recordConfiguration(_ configuration: Configuration) {
        lock.lock()
        configurations.append(configuration)
        lock.unlock()
    }

    private func recordRequest(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Data, URLResponse))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: SynologyError.network(message: "No HTTP transport handler configured"))
            return
        }

        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func makeHTTPURLResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

func makeSynologyEnvelope<T: Encodable>(_ data: T) throws -> Data {
    try JSONEncoder().encode(TestSynologyEnvelope(success: true, data: data))
}

func requestBodyData(_ request: URLRequest) -> Data? {
    if let data = request.httpBody {
        return data
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    let bufferSize = 1024
    var data = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read < 0 {
            return nil
        }
        if read == 0 {
            break
        }
        data.append(buffer, count: read)
    }

    return data
}

func makeJSONData(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

func makeSong(id: String = "music_1", title: String = "Track 1") -> Song {
    Song(
        id: id,
        title: title,
        type: "file",
        path: "/music/\(title).mp3",
        additional: SongAdditional(
            songAudio: SongAudio(
                bitrate: 320000,
                channel: 2,
                codec: "mp3",
                container: "mp3",
                duration: 180,
                filesize: 1_024,
                frequency: 44_100
            ),
            songRating: SongRating(rating: 5),
            songTag: SongTag(
                album: "Album",
                albumArtist: "Artist",
                artist: "Artist",
                comment: "",
                composer: "Composer",
                disc: 1,
                genre: "Pop",
                track: 1,
                year: 2024
            )
        )
    )
}

func makePlaylist(id: String = "playlist_1", song: Song = makeSong()) -> Playlist {
    Playlist(
        id: id,
        library: "shared",
        name: "Favorites",
        sharingStatus: "private",
        type: "normal",
        additional: PlaylistAdditional(
            songs: [song],
            songsOffset: 0,
            songsTotal: 1
        )
    )
}

func makeAudioStationInfo(version: Int = 3383) -> AudioStationInfo {
    AudioStationInfo(
        enable_equalizer: false,
        playing_queue_max: 8192,
        same_subnet: true,
        enable_user_home: true,
        has_aac: true,
        support_bluetooth: true,
        version_string: "6.5.7-\(version)",
        has_music_share: true,
        version: version,
        sid: nil,
        enable_personal_library: true,
        settings: AudioStationInfoSettings(
            disable_upnp: false,
            enable_download: true,
            transcode_to_mp3: true,
            prefer_using_html5: true,
            audio_show_virtual_library: true
        ),
        support_usb: true,
        dsd_decode_capability: true,
        browse_personal_library: "all",
        serial_number: "SN123",
        privilege: AudioStationInfoPrivilege(
            tag_edit: true,
            sharing: true,
            upnp_browse: true,
            playlist_edit: true,
            remote_player: true
        ),
        support_virtual_library: true,
        remote_controller: true,
        transcode_capability: ["mp3"],
        is_manager: true
    )
}

func XCTAssertURL(_ url: URL, contains queryItems: [String: String], file: StaticString = #filePath, line: UInt = #line) {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let actual = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    for (key, value) in queryItems {
        XCTAssertEqual(actual[key], value, "Missing query item \(key)", file: file, line: line)
    }
}

struct TestApiInfoProvider: ApiInfoProviding {
    var nodes: [String: ApiInfoNode] = [:]
    var onRefresh: (@Sendable () throws -> Void)?

    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
        if let node = nodes[apiName] {
            return node
        }
        return ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil)
    }

    func refresh() async throws {
        try onRefresh?()
    }

    func loadFromCacheOrRefresh() async throws {}
}

struct TestAuthProvider: AuthenticationProviding {
    var result: Result<AuthResult, Error>

    func login(username: String, password: String, otpCode: String?) async throws -> AuthResult {
        _ = (username, password, otpCode)
        return try result.get()
    }
}

struct TestPingPong: PingPongProviding {
    var results: [ConnectionType: String] = [:]
    var firstResult: SynologyConnection?
    var singleURLReachable = false

    func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String] {
        results
    }

    func pingpongFirst(connections: [ConnectionType: [String]]) async -> (type: ConnectionType, url: String)? {
        guard let firstResult else { return nil }
        guard connections[firstResult.type]?.contains(firstResult.url) == true else {
            return nil
        }
        return (firstResult.type, firstResult.url)
    }

    func pingpong(url: String) async -> Bool {
        singleURLReachable
    }
}

private struct TestSynologyEnvelope<T: Encodable>: Encodable {
    let success: Bool
    let data: T
}
