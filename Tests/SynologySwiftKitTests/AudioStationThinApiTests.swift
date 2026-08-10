import XCTest
@testable import SynologySwiftKit

final class AudioStationThinApiTests: XCTestCase {
    func testAudioStationClientExposesAllSubmodules() {
        let api = AudioStationClient(apiClient: MockApiClient(), keyValueStorage: MockKeyValueStorage())

        XCTAssertNotNil(api.pins)
        XCTAssertNotNil(api.folders)
        XCTAssertNotNil(api.albums)
        XCTAssertNotNil(api.artists)
        XCTAssertNotNil(api.composers)
        XCTAssertNotNil(api.genres)
        XCTAssertNotNil(api.songs)
        XCTAssertNotNil(api.playlists)
        XCTAssertNotNil(api.lyrics)
        XCTAssertNotNil(api.search)
        XCTAssertNotNil(api.covers)
        XCTAssertNotNil(api.stream)
        XCTAssertNotNil(api.info)
        XCTAssertNotNil(api.tagEditor)
    }

    func testConcurrentSubmoduleAccessReturnsStableInstances() async {
        let api = AudioStationClient(apiClient: MockApiClient(), keyValueStorage: MockKeyValueStorage())

        let coverIdentifiers = await withTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0 ..< 128 {
                group.addTask {
                    ObjectIdentifier(api.covers)
                }
            }

            var identifiers: [ObjectIdentifier] = []
            for await identifier in group {
                identifiers.append(identifier)
            }
            return identifiers
        }

        XCTAssertEqual(Set(coverIdentifiers).count, 1)
        XCTAssertTrue(api.stream === api.stream)
    }

    func testCollectionApisReturnDecodedLists() async throws {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.apiName {
            case SynologyApi.AudioStation.ALBUM.name:
                return AlbumListResult(
                    offset: 0,
                    total: 1,
                    albums: [Album(name: "Album", artist: "Artist", albumArtist: "Album Artist", displayArtist: "Display", year: 2024, additional: AlbumAdditional(avgRating: AlbumAvgRating(rating: 5)))]
                )
            case SynologyApi.AudioStation.ARTIST.name:
                return ArtistListResult(offset: 0, total: 1, artists: [Artist(name: "Artist")])
            case SynologyApi.AudioStation.COMPOSER.name:
                return ComposerListResult(offset: 0, total: 1, composers: [Composer(name: "Composer")])
            case SynologyApi.AudioStation.GENRE.name:
                return GenreListResult(offset: 0, total: 1, genres: [Genre(name: "Genre")])
            case SynologyApi.AudioStation.SEARCH.name:
                XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "personal")
                return SearchResult(
                    albumTotal: 1,
                    albums: [Album(name: "Album", artist: "Artist", albumArtist: "Album Artist", displayArtist: "Display", year: 2024, additional: nil)],
                    artistTotal: 1,
                    artists: [Artist(name: "Artist")],
                    songTotal: 1,
                    songs: [makeSong()]
                )
            case SynologyApi.AudioStation.FOLDER.name:
                XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "25")
                XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "50")
                return FolderListResult(
                    id: "root",
                    items: [Folder(id: "folder_1", path: "/music", isPersonal: false, title: "Music", type: "folder", additional: nil)],
                    offset: 50,
                    total: 3,
                    folderTotal: 1
                )
            default:
                throw SynologyError.network(message: "Unexpected endpoint \(endpoint.apiName)")
            }
        }

        let albumResult = try await AlbumApi(apiClient: apiClient).list(
            limit: 10,
            offset: 0,
            keyword: "A",
            sort: SynologySortDescriptor(field: "name", direction: .ascending)
        )
        let artistResult = try await ArtistApi(apiClient: apiClient).list(limit: 10, offset: 0)
        let composerResult = try await ComposerApi(apiClient: apiClient).list(limit: 10, offset: 0)
        let genreResult = try await GenreApi(apiClient: apiClient).list(limit: 10, offset: 0)
        let searchResult = try await SearchApi(apiClient: apiClient).list(
            keyword: "track",
            libraryScope: .personal
        )
        let folderResult = try await FolderApi(apiClient: apiClient).list(id: nil, limit: 25, offset: 50)

        XCTAssertEqual(albumResult.total, 1)
        XCTAssertEqual(albumResult.items.first?.additional?.avgRating?.rating, 5)
        XCTAssertEqual(artistResult.items.first?.name, "Artist")
        XCTAssertEqual(composerResult.items.first?.name, "Composer")
        XCTAssertEqual(genreResult.items.first?.name, "Genre")
        XCTAssertEqual(searchResult.songs.total, 1)
        XCTAssertEqual(folderResult.total, 3)
    }

    func testAlbumApiListCanMatchRecentlyAddedAlbumEndpointContract() async throws {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.apiName, SynologyApi.AudioStation.ALBUM.name)
            XCTAssertEqual(endpoint.method, "list")
            XCTAssertEqual(endpoint.version, 3)
            XCTAssertEqual(endpoint.httpMethod, .post)
            XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "50")
            XCTAssertEqual(endpoint.parameters["offset"]?.stringValue, "0")
            XCTAssertEqual(endpoint.parameters["library"]?.stringValue, "shared")
            XCTAssertEqual(endpoint.parameters["sort_by"]?.stringValue, "time")
            XCTAssertEqual(endpoint.parameters["sort_direction"]?.stringValue, "desc")
            XCTAssertEqual(endpoint.parameters["additional"]?.stringValue, "avg_rating")

            return AlbumListResult(offset: 0, total: 1, albums: [
                Album(
                    name: "Recent Album",
                    artist: "Artist",
                    albumArtist: "Album Artist",
                    displayArtist: "Display",
                    year: 2025,
                    additional: AlbumAdditional(avgRating: AlbumAvgRating(rating: 4))
                )
            ])
        }

        let result = try await AlbumApi(apiClient: apiClient).list(
            limit: 50,
            offset: 0,
            libraryScope: .shared,
            includeFields: "avg_rating",
            sort: SynologySortDescriptor(field: "time", direction: .descending)
        )
        XCTAssertEqual(result.total, 1)
        XCTAssertEqual(result.items.first?.name, "Recent Album")
        XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
    }

    func testLyricsApiSupportsGetAndSearch() async throws {
        let apiClient = MockApiClient()
        let lyricsResult = try JSONDecoder().decode(LyricsResult.self, from: makeJSONData(["lyrics": "hello world"]))
        let searchResult = try JSONDecoder().decode(
            LyricsSearchResult.self,
            from: makeJSONData([
                "total": 1,
                "lyrics": [[
                    "id": "candidate_1",
                    "title": "Song",
                    "artist": "Artist",
                    "partial_lyrics": "Preview",
                    "plugin": "LRCLIB",
                    "additional": ["full_lyrics": "[00:01.00]Hello world"],
                ]],
            ])
        )
        apiClient.requestHandler = { endpoint in
            switch endpoint.apiName {
            case SynologyApi.AudioStation.LYRICS.name:
                return lyricsResult
            case SynologyApi.AudioStation.LYRICS_SEARCH.name:
                XCTAssertEqual(endpoint.version, 2)
                XCTAssertEqual(endpoint.parameters["limit"]?.stringValue, "10")
                XCTAssertNil(endpoint.parameters["offset"])
                XCTAssertEqual(endpoint.parameters["additional"]?.stringValue, "full_lyrics")
                return searchResult
            default:
                throw SynologyError.network(message: "Unexpected endpoint")
            }
        }

        let lyrics = try await LyricsApi(apiClient: apiClient).get(id: "music_1")
        let search = try await LyricsApi(apiClient: apiClient).search(title: "Song", artist: "Artist")

        XCTAssertEqual(lyrics, "hello world")
        XCTAssertEqual(search.total, 1)
        XCTAssertEqual(search.items.first?.preview, "Preview")
        XCTAssertEqual(search.items.first?.plugin, "LRCLIB")
        XCTAssertEqual(search.items.first?.fullLyrics, "[00:01.00]Hello world")
    }

    func testLyricsApiThrowsWhenLyricsMissing() async {
        let apiClient = MockApiClient()
        apiClient.mockResponse = try? JSONDecoder().decode(LyricsResult.self, from: makeJSONData(["lyrics": NSNull()]))

        do {
            _ = try await LyricsApi(apiClient: apiClient).get(id: "music_1")
            XCTFail("Expected missing lyrics to throw")
        } catch let SynologyError.api(code, _) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testLyricsApiSavesLyricsWithoutOverwritingExistingTags() async throws {
        let path = #"/music/Artist/"Quoted" \ Song.flac"#
        let file = TagEditorData(
            album: "Album",
            albumArtist: "Album Artist",
            artist: "Artist",
            comment: "Keep this comment",
            composer: "Composer",
            disc: 2,
            genre: "Pop",
            path: path,
            title: "Track",
            track: 3,
            year: 2026
        )
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.parameters["action"]?.stringValue {
            case "load":
                return TagEditorResult(
                    success: true,
                    readFailCount: 0,
                    lyrics: "Old lyrics",
                    files: [file]
                )
            case "apply":
                return TagEditorResult(
                    success: true,
                    readFailCount: 0,
                    lyrics: "New lyrics",
                    files: [file]
                )
            default:
                throw SynologyError.network(message: "Unexpected action")
            }
        }

        let result = try await LyricsApi(apiClient: apiClient).save("New lyrics", forPath: path)

        XCTAssertEqual(result.lyrics, "New lyrics")
        XCTAssertEqual(apiClient.requestedEndpoints.count, 2)

        let loadAudioInfos = try XCTUnwrap(apiClient.requestedEndpoints[0].parameters["audioInfos"]?.stringValue)
        let loadJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(loadAudioInfos.utf8)) as? [[String: String]]
        )
        XCTAssertEqual(loadJSON, [["path": path]])

        let applyData = try XCTUnwrap(apiClient.requestedEndpoints[1].parameters["data"]?.stringValue)
        let requests = try JSONDecoder().decode([TagEditorRequest].self, from: Data(applyData.utf8))
        let request = try XCTUnwrap(requests.first)
        let audioInfo = try XCTUnwrap(request.audioInfos.first)
        XCTAssertEqual(request.audioInfos.count, 1)
        XCTAssertEqual(audioInfo.path, file.path)
        XCTAssertEqual(audioInfo.title, file.title)
        XCTAssertEqual(audioInfo.artist, file.artist)
        XCTAssertEqual(audioInfo.album, file.album)
        XCTAssertEqual(audioInfo.albumArtist, file.albumArtist)
        XCTAssertEqual(audioInfo.comment, file.comment)
        XCTAssertEqual(audioInfo.composer, file.composer)
        XCTAssertEqual(audioInfo.genre, file.genre)
        XCTAssertEqual(audioInfo.track, file.track)
        XCTAssertEqual(audioInfo.disc, file.disc)
        XCTAssertEqual(audioInfo.year, file.year)
        XCTAssertEqual(request.lyrics, "New lyrics")
        XCTAssertEqual(request.title, file.title)
        XCTAssertEqual(request.artist, file.artist)
        XCTAssertEqual(request.album, file.album)
        XCTAssertEqual(request.albumArtist, file.albumArtist)
        XCTAssertEqual(request.comment, file.comment)
        XCTAssertEqual(request.composer, file.composer)
        XCTAssertEqual(request.genre, file.genre)
        XCTAssertEqual(request.track, String(file.track))
        XCTAssertEqual(request.disc, String(file.disc))
        XCTAssertEqual(request.year, String(file.year))
        XCTAssertEqual(request.coverType, "original_image")
        XCTAssertEqual(request.coverPath, "")
        XCTAssertEqual(request.codePage, "SYNO_NO_CODE_PAGE_CONVERT")
    }

    func testTagEditorApiSavesRemoteArtworkWithoutOverwritingLyricsOrTags() async throws {
        let songPath = "/music/Artist/Song.flac"
        let coverURL = try XCTUnwrap(URL(string: "https://example.com/cover.jpg"))
        let file = TagEditorData(
            album: "Album",
            albumArtist: "Album Artist",
            artist: "Artist",
            comment: "Comment",
            composer: "Composer",
            disc: 1,
            genre: "Pop",
            path: songPath,
            title: "Song",
            track: 2,
            year: 2026
        )
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.parameters["action"]?.stringValue {
            case "load":
                return TagEditorResult(
                    success: true,
                    readFailCount: 0,
                    lyrics: "Existing lyrics",
                    files: [file]
                )
            case "apply":
                return TagEditorResult(
                    success: true,
                    readFailCount: 0,
                    lyrics: "Existing lyrics",
                    files: [file]
                )
            default:
                throw SynologyError.network(message: "Unexpected action")
            }
        }

        _ = try await TagEditorApi(apiClient: apiClient).saveArtwork(
            .imageFromURL(url: coverURL),
            forPath: songPath
        )

        let applyData = try XCTUnwrap(apiClient.requestedEndpoints.last?.parameters["data"]?.stringValue)
        let requests = try JSONDecoder().decode([TagEditorRequest].self, from: Data(applyData.utf8))
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.lyrics, "Existing lyrics")
        XCTAssertEqual(request.title, file.title)
        XCTAssertEqual(request.artist, file.artist)
        XCTAssertEqual(request.album, file.album)
        XCTAssertEqual(request.albumArtist, file.albumArtist)
        XCTAssertEqual(request.comment, file.comment)
        XCTAssertEqual(request.coverType, "image_from_URL")
        XCTAssertEqual(request.coverPath, coverURL.absoluteString)
        XCTAssertEqual(
            TagEditorArtwork.imageFromURL(url: coverURL),
            TagEditorArtwork(type: "image_from_URL", path: coverURL.absoluteString)
        )
    }

    func testLyricsApiDoesNotApplyWhenOriginalTagsCannotBeLoaded() async {
        let apiClient = MockApiClient()
        apiClient.mockResponse = TagEditorResult(
            success: true,
            readFailCount: 1,
            lyrics: nil,
            files: []
        )

        do {
            _ = try await LyricsApi(apiClient: apiClient).save("Lyrics", forPath: "/music/file.mp3")
            XCTFail("Expected missing original tags to throw")
        } catch let SynologyError.api(code, _) {
            XCTAssertEqual(code, -1)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
        XCTAssertEqual(apiClient.requestedEndpoints.first?.parameters["action"]?.stringValue, "load")
    }

    func testTagEditorApiLoadAndApply() async throws {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.parameters["action"]?.stringValue {
            case "load":
                return TagEditorResult(success: true, readFailCount: 0, lyrics: "lyrics", files: [TagEditorData(album: "Album", albumArtist: "Artist", artist: "Artist", comment: "", composer: "Composer", disc: 1, genre: "Pop", path: "/music/file.mp3", title: "Track", track: 1, year: 2024)])
            case "apply":
                return TagEditorResult(success: true, readFailCount: 0, lyrics: nil, files: [])
            default:
                throw SynologyError.network(message: "Unexpected action")
            }
        }

        let api = TagEditorApi(apiClient: apiClient)
        let loadResult = try await api.load(path: "/music/file.mp3")
        let update = TagEditorUpdate(
            files: loadResult.files,
            title: "Track",
            artist: "Artist",
            album: "Album",
            albumArtist: "Artist",
            composer: "Composer",
            genre: "Pop",
            lyrics: "lyrics",
            track: 1,
            disc: 1,
            year: 2024
        )
        let applyResult = try await api.apply(update: update)

        XCTAssertEqual(loadResult.lyrics, "lyrics")
        XCTAssertEqual(loadResult.readFailedFileCount, 0)
        XCTAssertEqual(applyResult.files.count, 0)
    }

    func testTagEditorApiThrowsOnFailedResult() async {
        let apiClient = MockApiClient()
        apiClient.mockResponse = TagEditorResult(success: false, readFailCount: 1, lyrics: nil, files: [])

        do {
            _ = try await TagEditorApi(apiClient: apiClient).load(path: "/music/file.mp3")
            XCTFail("Expected load failure")
        } catch let SynologyError.api(code, _) {
            XCTAssertEqual(code, -1)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testPinApiSupportsListPinUnpinAndConvenienceMethods() async throws {
        let apiClient = MockApiClient()
        apiClient.requestHandler = { endpoint in
            switch endpoint.method {
            case "list":
                return PinListResult(offset: 0, total: 1, items: [PinItem(id: "pin_1", type: .folder, name: "Music", criteria: .folder("folder_1"))])
            case "pin":
                return SynologyResponse<PinOperationResult>(
                    success: true,
                    error: nil,
                    data: PinOperationResult(errors: [], items: [PinItem(id: "pin_1", type: .folder, name: "Music", criteria: .folder("folder_1"))])
                )
            case "unpin":
                return UnpinOperationResult(errors: [], items: ["pin_1"])
            default:
                throw SynologyError.network(message: "Unexpected pin method")
            }
        }

        let api = PinApi(apiClient: apiClient)
        let list = try await api.list()
        let item = try await api.pinFolder(folderId: "folder_1", name: "Music").item
        let unpin = try await api.unpin(ids: ["pin_1"])
        let album = try await api.pinAlbum(album: "Album", albumArtist: "Artist")
        let artist = try await api.pinArtist(artist: "Artist")
        let composer = try await api.pinComposer(composer: "Composer")
        let genre = try await api.pinGenre(genre: "Genre")

        XCTAssertEqual(list.total, 1)
        XCTAssertEqual(item?.id, "pin_1")
        XCTAssertEqual(unpin.removedIDs, ["pin_1"])
        XCTAssertTrue(unpin.removedAll)
        XCTAssertEqual(album.item?.type, .folder)
        XCTAssertEqual(artist.item?.id, "pin_1")
        XCTAssertEqual(composer.item?.id, "pin_1")
        XCTAssertEqual(genre.item?.id, "pin_1")
    }

    func testPinApiReturnsAlreadyExistsAsIdempotentSuccess() async throws {
        let apiClient = MockApiClient()
        apiClient.mockResponse = SynologyResponse<PinOperationResult>(
            success: false,
            error: SynologyApiError(code: 1002, errors: [1006]),
            data: nil
        )

        let result = try await PinApi(apiClient: apiClient).pin(
            type: .folder,
            name: "Music",
            criteria: .folder("folder_1")
        )
        guard case .alreadyExists = result else {
            return XCTFail("Expected alreadyExists result")
        }
    }
}
