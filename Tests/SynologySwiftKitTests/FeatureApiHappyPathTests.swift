import XCTest
@testable import SynologySwiftKit

final class FeatureApiHappyPathTests: XCTestCase {
    func testInfoApiReturnsCachedAudioStationInfo() async throws {
        let apiClient = MockApiClient()
        let storage = MockKeyValueStorage()
        let cachedInfo = makeAudioStationInfo(version: 4000)
        storage.setCodable(cachedInfo, forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO.keyName)
        storage.setDate(Date(), forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName)

        let infoApi = InfoApi(apiClient: apiClient, keyValueStorage: storage)
        let result = try await infoApi.query(usesCache: true)

        XCTAssertEqual(result.version, 4000)
        XCTAssertTrue(apiClient.requestedEndpoints.isEmpty)
    }

    func testInfoApiFetchesFromNetworkCachesResultAndSupportsExplicitSession() async throws {
        let apiClient = MockApiClient()
        let storage = MockKeyValueStorage()
        apiClient.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.method, "getinfo")
            XCTAssertEqual(endpoint.parameters["sid"]?.stringValue, "sid-1")
            XCTAssertEqual(endpoint.parameters["did"]?.stringValue, "did-1")
            return makeAudioStationInfo(version: 5000)
        }

        let infoApi = InfoApi(apiClient: apiClient, keyValueStorage: storage)
        let result = try await infoApi.query(using: SynologySession(sid: "sid-1", did: "did-1"))

        XCTAssertEqual(result.version, 5000)
        XCTAssertEqual(infoApi.cachedInfo()?.version, 5000)
        XCTAssertNotNil(storage.date(forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName))
    }

    func testInfoApiIgnoresExpiredCacheAndRefetches() async throws {
        let apiClient = MockApiClient()
        let storage = MockKeyValueStorage()
        storage.setCodable(makeAudioStationInfo(version: 3000), forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO.keyName)
        storage.setDate(Date(timeIntervalSinceNow: -(25 * 60 * 60)), forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName)
        apiClient.mockResponse = makeAudioStationInfo(version: 6000)

        let infoApi = InfoApi(apiClient: apiClient, keyValueStorage: storage)
        let result = try await infoApi.query(usesCache: true)

        XCTAssertEqual(result.version, 6000)
        XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
    }

    func testSongApiHappyPath() async throws {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.method {
            case "list":
                return SongListResult(offset: 0, total: 1, songs: [makeSong()])
            case "getinfo":
                return SongInfo(songs: [makeSong(id: "music_42", title: "Detail Track")])
            case "setrating":
                return EmptyData()
            default:
                throw SynologyError.network(message: "Unexpected method \(endpoint.method)")
            }
        }

        let songApi = SongApi(apiClient: apiClient)
        let list = try await songApi.list(limit: 10, offset: 0)
        let song = try await songApi.getInfo(id: "music_42")
        let ratingUpdate = try await songApi.setRating(id: "music_42", rating: 5)

        XCTAssertEqual(list.total, 1)
        XCTAssertEqual(song.title, "Detail Track")
        XCTAssertEqual(ratingUpdate.songID, "music_42")
        XCTAssertEqual(ratingUpdate.rating, 5)
        XCTAssertEqual(apiClient.requestedEndpoints.count, 3)
    }

    func testSongApiListUrlAndEmptyInfoFailure() async throws {
        let apiClient = MockApiClient()
        apiClient.buildUrlHandler = { endpoint in
            XCTAssertEqual(endpoint.method, "list")
            XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "personal")
            XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "5")
            XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "10")
            return URL(string: "https://mock.local/song-list")!
        }
        apiClient.requestHandler = { endpoint in
            if endpoint.method == "getinfo" {
                return SongInfo(songs: [])
            }
            throw SynologyError.network(message: "Unexpected method \(endpoint.method)")
        }

        let songApi = SongApi(apiClient: apiClient)
        let listURL = try await songApi.listURL(limit: 5, offset: 10, libraryScope: .personal)
        XCTAssertEqual(listURL.absoluteString, "https://mock.local/song-list")

        do {
            _ = try await songApi.getInfo(id: "missing")
            XCTFail("Expected missing song error")
        } catch let SynologyError.api(code, message) {
            XCTAssertEqual(code, -1)
            XCTAssertEqual(message, "query song failed")
        }
    }

    func testPlaylistApiHappyPath() async throws {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.method {
            case "list":
                return PlaylistListResult(offset: 0, total: 1, playlists: [makePlaylist()])
            case "getinfo":
                return PlaylistGetInfoResult(playlists: [makePlaylist()])
            case "create":
                return PlaylistCreateResult(id: "playlist_new")
            case "delete":
                return PlaylistDeleteResult(errors: [])
            case "updatesongs":
                return EmptyData()
            default:
                throw SynologyError.network(message: "Unexpected method \(endpoint.method)")
            }
        }

        let playlistApi = PlaylistApi(apiClient: apiClient)
        let list = try await playlistApi.list(limit: 20, offset: 0)
        let songs = try await playlistApi.getSongs(id: "playlist_1", libraryScope: .shared, limit: 20, offset: 0)
        let playlistRef = try await playlistApi.create(name: "Roadtrip", libraryScope: .shared)
        let addSongsResult = try await playlistApi.addSongs(id: "playlist_new", songIDs: ["music_1"])
        let deletion = try await playlistApi.delete(id: "playlist_new")

        XCTAssertEqual(list.total, 1)
        XCTAssertEqual(songs.items.count, 1)
        XCTAssertEqual(playlistRef.id, "playlist_new")
        XCTAssertEqual(addSongsResult.playlistID, "playlist_new")
        XCTAssertTrue(deletion.deleted)
    }

    func testPlaylistApiCreateSmartUsesAndOrConjunctionParameters() async throws {
        let cases: [(SmartPlaylistMatchRule, String)] = [(.all, "and"), (.any, "or")]
        let rules = #"[{"tag":4,"op":4,"tagval":"/music/收藏/","interval":0}]"#

        for (matchRule, expectedConjunction) in cases {
            let apiClient = MockApiClient()
            apiClient.requestHandler = { endpoint in
                XCTAssertEqual(endpoint.apiName, SynologyApi.AudioStation.PLAYLIST.name)
                XCTAssertEqual(endpoint.method, "createsmart")
                XCTAssertEqual(endpoint.parameters["name"]?.stringValue, "Smart")
                XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "personal")
                XCTAssertEqual(endpoint.parameters["conj_rule"]?.stringValue, expectedConjunction)
                XCTAssertEqual(endpoint.parameters["rules_json"]?.stringValue, rules)
                return PlaylistCreateResult(id: "smart_1")
            }

            let playlistApi = PlaylistApi(apiClient: apiClient)
            let playlist = try await playlistApi.createSmart(
                name: "Smart",
                definition: SmartPlaylistDefinition(
                    scope: .personal,
                    matchRule: matchRule,
                    serializedRules: rules
                )
            )

            XCTAssertEqual(playlist.id, "smart_1")
            XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
        }
    }

    func testPlaylistApiCreateFolderSmartUsesSinglePathIncludesRule() async throws {
        let cases = [
            ("/music/Albums", "/music/Albums/"),
            ("/music/Albums/", "/music/Albums/"),
            ("/music/Albums///", "/music/Albums/"),
            (#"/music/ 中文 "精选" "#, #"/music/ 中文 "精选" /"#),
            (#"/music/合集\现场"#, #"/music/合集\现场/"#),
            ("/volume2/music/100%20Hits", "/volume2/music/100%20Hits/")
        ]

        for (folderPath, expectedPath) in cases {
            let apiClient = MockApiClient()
            apiClient.requestHandler = { endpoint in
                XCTAssertEqual(endpoint.apiName, SynologyApi.AudioStation.PLAYLIST.name)
                XCTAssertEqual(endpoint.method, "createsmart")
                XCTAssertEqual(endpoint.version, 2)
                XCTAssertEqual(endpoint.httpMethod, .post)
                XCTAssertEqual(Set(endpoint.parameters.keys), Set(["name", "library", "conj_rule", "rules_json"]))
                XCTAssertEqual(endpoint.parameters["name"]?.stringValue, "Folder Smart")
                XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "personal")
                XCTAssertEqual(endpoint.parameters["conj_rule"]?.stringValue, "and")
                let json = try XCTUnwrap(endpoint.parameters["rules_json"]?.stringValue)
                let rules = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
                XCTAssertEqual(rules.count, 1)
                let rule = try XCTUnwrap(rules.first)
                XCTAssertEqual(Set(rule.keys), Set(["tag", "op", "tagval", "interval"]))
                XCTAssertEqual(rule["tag"] as? Int, 4)
                XCTAssertEqual(rule["op"] as? Int, 4)
                XCTAssertEqual(rule["tagval"] as? String, expectedPath)
                XCTAssertEqual(rule["interval"] as? Int, 0)
                return PlaylistCreateResult(id: "folder_smart_1")
            }

            let playlist = try await PlaylistApi(apiClient: apiClient).createFolderSmart(
                name: "Folder Smart", folderPath: folderPath
            )

            XCTAssertEqual(playlist.id, "folder_smart_1")
            XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
        }
    }

    func testPlaylistApiCreateFolderSmartForwardsLibraryScope() async throws {
        for scope in [SynologyLibraryScope.shared, .personal] {
            let apiClient = MockApiClient()
            apiClient.mockResponse = PlaylistCreateResult(id: "folder_smart_1")

            _ = try await PlaylistApi(apiClient: apiClient).createFolderSmart(
                name: "Folder Smart", folderPath: "/music/Albums", libraryScope: scope
            )

            XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
            XCTAssertEqual(apiClient.requestedEndpoints.first?.parameters["library"]?.stringValue, scope.rawValue)
        }
    }

    func testPlaylistApiCreateFolderSmartRejectsAllLibraryWithoutRequests() async throws {
        let apiClient = MockApiClient()

        do {
            _ = try await PlaylistApi(apiClient: apiClient).createFolderSmart(
                name: "Folder Smart", folderPath: "/music/Albums", libraryScope: .all
            )
            XCTFail("Expected invalid playlist library error")
        } catch let SynologyError.api(code, message) {
            XCTAssertEqual(code, -1)
            XCTAssertEqual(message, "Invalid playlist library scope")
        }

        XCTAssertTrue(apiClient.requestedEndpoints.isEmpty)
    }

    func testPlaylistApiCreateFolderSmartRejectsInvalidPathsWithoutRequests() async throws {
        let invalidPaths = [
            "", "   ", "\t\n", "/", "///", "root", "music", "music_shared", "dir_123",
            "music/Albums", " /music/Albums", "/music/.", "/music/../Albums",
            "/music/Albums/../", "/music//Albums", "//music/Albums",
            "/music/Albums\u{0}", "/music/Albums\n", "file:///music/Albums"
        ]

        for folderPath in invalidPaths {
            let apiClient = MockApiClient()
            apiClient.mockResponse = PlaylistCreateResult(id: "unexpected")

            do {
                _ = try await PlaylistApi(apiClient: apiClient).createFolderSmart(
                    name: "Invalid", folderPath: folderPath
                )
                XCTFail("Expected invalid folder path error for \(folderPath.debugDescription)")
            } catch let SynologyError.api(code, message) {
                XCTAssertEqual(code, -1)
                XCTAssertEqual(message, "Invalid folder path")
            }

            XCTAssertTrue(apiClient.requestedEndpoints.isEmpty, folderPath.debugDescription)
        }
    }

    func testPlaylistApiCreateFolderSmartPropagatesRequestErrors() async throws {
        let errors: [SynologyError] = [
            .api(code: 105, message: "Permission denied"),
            .network(message: "Connection failed"),
            .sessionExpired(code: 119, message: "Session expired")
        ]

        for expectedError in errors {
            let apiClient = MockApiClient()
            apiClient.mockError = expectedError

            do {
                _ = try await PlaylistApi(apiClient: apiClient).createFolderSmart(
                    name: "Folder Smart", folderPath: "/music/Albums"
                )
                XCTFail("Expected request error")
            } catch let error as SynologyError {
                switch (expectedError, error) {
                case let (.api(expectedCode, expectedMessage), .api(code, message)),
                     let (.sessionExpired(expectedCode, expectedMessage), .sessionExpired(code, message)):
                    XCTAssertEqual(code, expectedCode)
                    XCTAssertEqual(message, expectedMessage)
                case let (.network(expectedMessage), .network(message)):
                    XCTAssertEqual(message, expectedMessage)
                default:
                    XCTFail("Unexpected error \(error)")
                }
            }

            XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
        }
    }

    func testPlaylistApiCoversRemainingOperationsAndFallbacks() async throws {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.method {
            case "getinfo":
                return PlaylistGetInfoResult(playlists: [])
            case "createsmart":
                XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "personal")
                return PlaylistCreateResult(id: "smart_1")
            case "rename":
                return PlaylistRenameResult(id: "playlist_renamed")
            case "removemissing":
                return EmptyData()
            case "updatesongs":
                XCTAssertNil(endpoint.parameters["songs"])
                return EmptyData()
            case "delete":
                return PlaylistDeleteResult(errors: ["failed"])
            default:
                throw SynologyError.network(message: "Unexpected method \(endpoint.method)")
            }
        }

        let playlistApi = PlaylistApi(apiClient: apiClient)
        let songs = try await playlistApi.getSongs(id: "playlist_1", libraryScope: .shared, limit: 10, offset: 0)
        let smartPlaylist = try await playlistApi.createSmart(
            name: "Smart",
            definition: SmartPlaylistDefinition(scope: .personal, matchRule: .all, serializedRules: "[]")
        )
        let renamedPlaylist = try await playlistApi.rename(id: "playlist_1", name: "Renamed")
        let removeMissingResult = try await playlistApi.removeMissing(id: "playlist_1")
        let addSongsResult = try await playlistApi.addSongs(id: "playlist_1", songIDs: [])
        let deletion = try await playlistApi.delete(id: "playlist_1")

        XCTAssertEqual(songs.total, 0)
        XCTAssertTrue(songs.items.isEmpty)
        XCTAssertEqual(smartPlaylist.id, "smart_1")
        XCTAssertEqual(renamedPlaylist.id, "playlist_renamed")
        XCTAssertEqual(removeMissingResult.playlistID, "playlist_1")
        XCTAssertEqual(addSongsResult.playlistID, "playlist_1")
        XCTAssertFalse(deletion.deleted)
    }

    func testCoverAndStreamApisBuildExpectedEndpoints() async throws {
        let apiClient = MockApiClient()
        apiClient.buildUrlHandler = { endpoint in
            let method = endpoint.method.isEmpty ? "custom" : endpoint.method
            return URL(string: "https://mock.local/\(method)")!
        }

        let coverApi = CoverApi(urlBuilder: apiClient)
        let streamApi = StreamApi(
            urlBuilder: apiClient,
            transcodeCapabilityProvider: StubAudioTranscodeCapabilityProvider()
        )

        _ = try await coverApi.songCoverURL(songID: "music_1", libraryScope: .shared)
        _ = try await streamApi.playbackURL(
            for: SongPlaybackSource(
                id: "music_v_1",
                path: "/music/file.flac",
                bitrate: 320000,
                frequency: 44_100
            ),
            quality: .HIGH
        )

        XCTAssertEqual(apiClient.builtUrlEndpoints.count, 2)

        let coverEndpoint = apiClient.builtUrlEndpoints[0]
        XCTAssertEqual(coverEndpoint.apiName, SynologyApi.AudioStation.COVER.name)
        XCTAssertEqual(coverEndpoint.method, "getsongcover")
        XCTAssertEqual(coverEndpoint.parameters["id"]?.stringValue, "music_1")

        let streamEndpoint = apiClient.builtUrlEndpoints[1]
        XCTAssertEqual(streamEndpoint.apiName, SynologyApi.AudioStation.STREAM.name)
        XCTAssertEqual(streamEndpoint.method, "transcode")
        XCTAssertEqual(streamEndpoint.pathSuffix, "/0.mp3")
        XCTAssertEqual(streamEndpoint.parameters["id"]?.stringValue, "music_v_1")
    }

    func testCoverApiBuildsAllCoverVariants() async throws {
        let apiClient = MockApiClient()
        apiClient.buildUrlHandler = { endpoint in
            URL(string: "https://mock.local/\(endpoint.method)")!
        }
        let coverApi = CoverApi(urlBuilder: apiClient)

        let songURL = try await coverApi.songCoverURL(songID: "song1")
        let albumURL = try await coverApi.albumCoverURL(albumName: "Album", albumArtistName: "Artist")
        let artistURL = try await coverApi.artistCoverURL(artistName: "Artist")
        let composerURL = try await coverApi.composerCoverURL(composerName: "Composer")

        XCTAssertEqual(songURL.lastPathComponent, "getsongcover")
        XCTAssertEqual(albumURL.lastPathComponent, "getcover")
        XCTAssertEqual(artistURL.lastPathComponent, "getcover")
        XCTAssertEqual(composerURL.lastPathComponent, "getcover")
        XCTAssertEqual(apiClient.builtUrlEndpoints.count, 4)
    }

    func testStreamApiChoosesStreamAndTranscodeBranches() async throws {
        let apiClient = MockApiClient()
        apiClient.buildUrlHandler = { endpoint in
            URL(string: "https://mock.local/\(endpoint.method)")!
        }
        let api = StreamApi(
            urlBuilder: apiClient,
            transcodeCapabilityProvider: StubAudioTranscodeCapabilityProvider()
        )

        _ = try await api.playbackURL(for: SongPlaybackSource(id: "track1", path: "/music/file.m4a", bitrate: 400_000, frequency: 44_100, fileExtension: ".aac"), quality: .HIGH)
        _ = try await api.playbackURL(for: SongPlaybackSource(id: "track2", path: "/music/file.dsf", bitrate: 1000, frequency: 44_100, fileExtension: ".dsf"), quality: .HIGH)
        _ = try await api.playbackURL(for: SongPlaybackSource(id: "track3", path: "/music/file.flac", bitrate: 1000, frequency: 44_100), quality: .ORIGINAL)
        _ = try await api.playbackURL(for: SongPlaybackSource(id: "track4", path: "/music/file.flac", bitrate: 500_000, frequency: 44_100), quality: .LOW)
        _ = try await api.playbackURL(for: SongPlaybackSource(id: "music_p_v_1", path: "/music/file.flac", bitrate: 1000, frequency: 44_100), quality: .LOW)

        XCTAssertEqual(apiClient.builtUrlEndpoints[0].method, "transcode")
        XCTAssertEqual(apiClient.builtUrlEndpoints[0].pathSuffix, "/0.mp3")
        XCTAssertEqual(apiClient.builtUrlEndpoints[1].method, "transcode")
        XCTAssertEqual(apiClient.builtUrlEndpoints[1].parameters["bitrate"]?.stringValue, "320000")
        XCTAssertEqual(apiClient.builtUrlEndpoints[2].method, "stream")
        XCTAssertEqual(apiClient.builtUrlEndpoints[3].parameters["bitrate"]?.stringValue, "128000")
        XCTAssertEqual(apiClient.builtUrlEndpoints[4].parameters["id"]?.stringValue, "music_p_v_1")
        XCTAssertEqual(apiClient.builtUrlEndpoints[4].parameters["bitrate"]?.stringValue, "128000")
    }

    func testStreamPlanAvoidsUpscalingAndKeepsFinalOutputMetadataTogether() throws {
        let api = StreamApi(
            urlBuilder: MockApiClient(),
            transcodeCapabilityProvider: StubAudioTranscodeCapabilityProvider()
        )

        let directPlan = try api.playbackPlan(
            for: SongPlaybackSource(
                id: "track1",
                path: "/music/file.mp3",
                bitrate: 96_000,
                frequency: 44_100,
                fileExtension: ".mp3"
            ),
            quality: .HIGH,
            preferredTranscodeFormat: .mp3,
            supportedTranscodeFormats: [.mp3, .wav]
        )
        XCTAssertEqual(
            directPlan,
            SongPlaybackPlan(
                method: .stream,
                outputFormat: "mp3",
                bitrate: nil,
                reason: .sourceWithinTargetBitrate
            )
        )

        let transcodePlan = try api.playbackPlan(
            for: SongPlaybackSource(
                id: "track2",
                path: "/music/file.flac",
                bitrate: 1_000_000,
                frequency: 96_000,
                fileExtension: ".flac"
            ),
            quality: .MEDIUM,
            preferredTranscodeFormat: .mp3,
            supportedTranscodeFormats: [.mp3, .wav]
        )
        XCTAssertEqual(transcodePlan.method, .transcode)
        XCTAssertEqual(transcodePlan.outputFormat, "mp3")
        XCTAssertEqual(transcodePlan.bitrate, 192_000)
        XCTAssertEqual(transcodePlan.fileExtension, ".mp3")
        XCTAssertEqual(transcodePlan.cacheIdentity, "transcode-mp3-192000")
    }

    func testStreamPlanUsesServerCapabilityForIncompatibleAndVirtualTracks() throws {
        let api = StreamApi(
            urlBuilder: MockApiClient(),
            transcodeCapabilityProvider: StubAudioTranscodeCapabilityProvider()
        )

        let wavPlan = try api.playbackPlan(
            for: SongPlaybackSource(
                id: "track1",
                path: "/music/file.dsf",
                bitrate: 5_000_000,
                frequency: 2_822_400,
                fileExtension: ".dsf"
            ),
            quality: .ORIGINAL,
            preferredTranscodeFormat: .mp3,
            supportedTranscodeFormats: [.wav]
        )
        XCTAssertEqual(wavPlan.method, .transcode)
        XCTAssertEqual(wavPlan.outputFormat, "wav")
        XCTAssertNil(wavPlan.bitrate)

        let virtualPlan = try api.playbackPlan(
            for: SongPlaybackSource(
                id: "music_v_1",
                path: "/music/disc.ape",
                bitrate: 0,
                frequency: 44_100,
                fileExtension: ".ape"
            ),
            quality: .LOW,
            preferredTranscodeFormat: .mp3,
            supportedTranscodeFormats: [.mp3]
        )
        XCTAssertEqual(virtualPlan.outputFormat, "mp3")
        XCTAssertEqual(virtualPlan.bitrate, 128_000)
        XCTAssertEqual(virtualPlan.reason, .virtualTrack)
    }

    func testTranscodePlanMapsMediaLoadFailureToInvalidTranscodedMedia() throws {
        let api = StreamApi(
            urlBuilder: MockApiClient(),
            transcodeCapabilityProvider: StubAudioTranscodeCapabilityProvider()
        )
        let transcodePlan = try api.playbackPlan(
            for: SongPlaybackSource(
                id: "music_v_1",
                path: "/music/disc.ape",
                bitrate: 0,
                frequency: 44_100,
                fileExtension: ".ape"
            ),
            quality: .ORIGINAL,
            preferredTranscodeFormat: .mp3,
            supportedTranscodeFormats: [.mp3]
        )
        let streamPlan = SongPlaybackPlan(
            method: .stream,
            outputFormat: "flac",
            bitrate: nil,
            reason: .originalRequested
        )

        XCTAssertEqual(
            transcodePlan.playbackError(for: .failedToLoadMediaData),
            .invalidTranscodedMedia
        )
        XCTAssertNil(
            streamPlan.playbackError(for: .failedToLoadMediaData)
        )
    }

    func testStreamPlanRejectsUnsupportedSourceWithoutServerTranscoding() {
        let api = StreamApi(
            urlBuilder: MockApiClient(),
            transcodeCapabilityProvider: StubAudioTranscodeCapabilityProvider()
        )

        XCTAssertThrowsError(
            try api.playbackPlan(
                for: SongPlaybackSource(
                    id: "track1",
                    path: "/music/file.ape",
                    bitrate: 900_000,
                    frequency: 44_100,
                    fileExtension: ".ape"
                ),
                quality: .ORIGINAL,
                preferredTranscodeFormat: .mp3,
                supportedTranscodeFormats: []
            )
        )
    }

    func testDsmInfoFileStationAndEncryptionClientsHappyPath() async throws {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.apiName {
            case SynologyApi.Core.DSM_INFO.name:
                return DsmInfo(
                    codepage: "utf-8",
                    model: "DS920+",
                    ram: 8192,
                    serial: "SERIAL",
                    temperature: 40,
                    temperatureWarn: false,
                    time: "now",
                    uptime: 100,
                    version: "7.2",
                    versionString: "DSM 7.2"
                )
            case SynologyApi.FileStation.DELETE.name:
                return FileStationClient.DeleteTask(taskid: "task-1")
            case SynologyApi.Core.ENCRYPTION.name:
                return ApiInfoEncryption(cipherkey: "key", ciphertoken: "token", publicKey: "public", serverTime: 123)
            default:
                throw SynologyError.network(message: "Unexpected api \(endpoint.apiName)")
            }
        }

        let dsmInfo = try await DSMInfoClient(apiClient: apiClient).query()
        let deleteTask = try await FileStationClient(apiClient: apiClient).delete(path: "/music/file.mp3")
        let encryption = try await EncryptionClient(apiClient: apiClient).queryInfo()

        XCTAssertEqual(dsmInfo.model, "DS920+")
        XCTAssertEqual(deleteTask.taskID, "task-1")
        XCTAssertEqual(encryption.cipherkey, "key")
    }

    func testDSMInfoClientMapsUnknownErrorsToNetworkError() async {
        let apiClient = MockApiClient()
        struct Dummy: Error {}
        apiClient.mockError = Dummy()

        do {
            _ = try await DSMInfoClient(apiClient: apiClient).query()
            XCTFail("Expected mapped network error")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "request failed")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

private struct StubAudioTranscodeCapabilityProvider: AudioTranscodeCapabilityProviding {
    let formats: Set<SongTranscodeFormat>

    init(formats: Set<SongTranscodeFormat> = [.mp3, .wav]) {
        self.formats = formats
    }

    func supportedTranscodeFormats() async throws -> Set<SongTranscodeFormat> {
        formats
    }
}
