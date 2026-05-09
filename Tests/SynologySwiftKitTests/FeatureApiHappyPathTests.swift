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

        let coverApi = CoverApi(apiClient: apiClient)
        let streamApi = StreamApi(apiClient: apiClient)

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
        let coverApi = CoverApi(apiClient: apiClient)

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
        let api = StreamApi(apiClient: apiClient)

        _ = try await api.playbackURL(for: SongPlaybackSource(id: "track1", path: "/music/file.m4a", bitrate: 1000, frequency: 44_100, fileExtension: ".aac"), quality: .HIGH)
        _ = try await api.playbackURL(for: SongPlaybackSource(id: "track2", path: "/music/file.dsf", bitrate: 1000, frequency: 44_100), quality: .HIGH)
        _ = try await api.playbackURL(for: SongPlaybackSource(id: "track3", path: "/music/file.flac", bitrate: 1000, frequency: 44_100), quality: .ORIGINAL)
        _ = try await api.playbackURL(for: SongPlaybackSource(id: "track4", path: "/music/file.flac", bitrate: 1000, frequency: 44_100), quality: .LOW)
        _ = try await api.playbackURL(for: SongPlaybackSource(id: "music_p_v_1", path: "/music/file.flac", bitrate: 1000, frequency: 44_100), quality: .LOW)

        XCTAssertEqual(apiClient.builtUrlEndpoints[0].method, "stream")
        XCTAssertEqual(apiClient.builtUrlEndpoints[0].pathSuffix, "/0.aac")
        XCTAssertEqual(apiClient.builtUrlEndpoints[1].method, "transcode")
        XCTAssertEqual(apiClient.builtUrlEndpoints[1].parameters["bitrate"]?.stringValue, "320000")
        XCTAssertEqual(apiClient.builtUrlEndpoints[2].method, "stream")
        XCTAssertEqual(apiClient.builtUrlEndpoints[3].parameters["bitrate"]?.stringValue, "128000")
        XCTAssertEqual(apiClient.builtUrlEndpoints[4].parameters["id"]?.stringValue, "music_p_v_1")
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
