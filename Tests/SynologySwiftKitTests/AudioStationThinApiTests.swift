import XCTest
@testable import SynologySwiftKit

final class AudioStationThinApiTests: XCTestCase {
    func testAudioStationApiExposesAllSubmodules() {
        let api = AudioStationApi(apiClient: MockApiClient(), keyValueStorage: MockKeyValueStorage())

        XCTAssertNotNil(api.pin)
        XCTAssertNotNil(api.folder)
        XCTAssertNotNil(api.album)
        XCTAssertNotNil(api.artist)
        XCTAssertNotNil(api.composer)
        XCTAssertNotNil(api.genre)
        XCTAssertNotNil(api.song)
        XCTAssertNotNil(api.playlist)
        XCTAssertNotNil(api.lyrics)
        XCTAssertNotNil(api.search)
        XCTAssertNotNil(api.cover)
        XCTAssertNotNil(api.stream)
        XCTAssertNotNil(api.info)
        XCTAssertNotNil(api.tagEditor)
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
                return SearchResult(
                    albumTotal: 1,
                    albums: [Album(name: "Album", artist: "Artist", albumArtist: "Album Artist", displayArtist: "Display", year: 2024, additional: nil)],
                    artistTotal: 1,
                    artists: [Artist(name: "Artist")],
                    songTotal: 1,
                    songs: [makeSong()]
                )
            case SynologyApi.AudioStation.FOLDER.name:
                return FolderListResult(
                    id: "root",
                    items: [Folder(id: "folder_1", path: "/music", isPersonal: false, title: "Music", type: "folder", additional: nil)],
                    offset: 0,
                    total: 1,
                    folderTotal: 1
                )
            default:
                throw SynologyError.network(message: "Unexpected endpoint \(endpoint.apiName)")
            }
        }

        let albumResult = try await AlbumApi(apiClient: apiClient).list(limit: 10, offset: 0, keyword: "A", sort: ("name", "asc"))
        let artistResult = try await ArtistApi(apiClient: apiClient).list(limit: 10, offset: 0)
        let composerResult = try await ComposerApi(apiClient: apiClient).list(limit: 10, offset: 0)
        let genreResult = try await GenreApi(apiClient: apiClient).list(limit: 10, offset: 0)
        let searchResult = try await SearchApi(apiClient: apiClient).list(keyword: "track")
        let folderResult = try await FolderApi(apiClient: apiClient).list(id: nil)

        XCTAssertEqual(albumResult.total, 1)
        XCTAssertEqual(albumResult.data.first?.additional?.avgRating?.rating, 5)
        XCTAssertEqual(artistResult.data.first?.name, "Artist")
        XCTAssertEqual(composerResult.data.first?.name, "Composer")
        XCTAssertEqual(genreResult.data.first?.name, "Genre")
        XCTAssertEqual(searchResult.songTotal, 1)
        XCTAssertEqual(folderResult.total, 1)
    }

    func testLyricsApiSupportsGetAndSearch() async throws {
        let apiClient = MockApiClient()
        let lyricsResult = try JSONDecoder().decode(LyricsResult.self, from: makeJSONData(["lyrics": "hello world"]))
        apiClient.requestHandler = { endpoint in
            switch endpoint.apiName {
            case SynologyApi.AudioStation.LYRICS.name:
                return lyricsResult
            case SynologyApi.AudioStation.LYRICS_SEARCH.name:
                return LyricsSearchResult(total: 1, items: [LyricsItem(id: "1", title: "Song", artist: "Artist", preview: "Preview")])
            default:
                throw SynologyError.network(message: "Unexpected endpoint")
            }
        }

        let lyrics = try await LyricsApi(apiClient: apiClient).get(id: "music_1")
        let search = try await LyricsApi(apiClient: apiClient).search(title: "Song", artist: "Artist")

        XCTAssertEqual(lyrics, "hello world")
        XCTAssertEqual(search.total, 1)
        XCTAssertEqual(search.data.first?.preview, "Preview")
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
        let request = TagEditorRequest(audioInfos: loadResult.files, lyrics: "lyrics", coverType: "", coverPath: "", title: "Track", artist: "Artist", album: "Album", comment: "", genre: "Pop", track: "1", disc: "1", year: "2024", albumArtist: "Artist", composer: "Composer", codePage: "utf-8")
        let applyResult = try await api.apply(request: request)

        XCTAssertTrue(loadResult.success)
        XCTAssertTrue(applyResult.success)
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
        let item = try await api.pinFolder(folderId: "folder_1", name: "Music")
        let unpin = try await api.unpin(ids: ["pin_1"])
        let album = try await api.pinAlbum(album: "Album", albumArtist: "Artist")
        let artist = try await api.pinArtist(artist: "Artist")
        let composer = try await api.pinComposer(composer: "Composer")
        let genre = try await api.pinGenre(genre: "Genre")

        XCTAssertEqual(list.total, 1)
        XCTAssertEqual(item.id, "pin_1")
        XCTAssertEqual(unpin.items, ["pin_1"])
        XCTAssertEqual(album.type, .folder)
        XCTAssertEqual(artist.id, "pin_1")
        XCTAssertEqual(composer.id, "pin_1")
        XCTAssertEqual(genre.id, "pin_1")
    }

    func testPinApiMapsAlreadyPinnedToIdempotentError() async {
        let apiClient = MockApiClient()
        apiClient.mockResponse = SynologyResponse<PinOperationResult>(
            success: false,
            error: SynologyApiError(code: 1002, errors: [1006]),
            data: nil
        )

        do {
            _ = try await PinApi(apiClient: apiClient).pin(type: .folder, name: "Music", criteria: .folder("folder_1"))
            XCTFail("Expected already pinned error")
        } catch let SynologyError.api(code, message) {
            XCTAssertEqual(code, 0)
            XCTAssertEqual(message, "pin already exists")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
