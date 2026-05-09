//
//  SongApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

public final class SongApi {
    private let apiClient: ApiRequestSending
    private let urlBuilder: ApiURLBuilding?

    init(apiClient: ApiRequestSending, urlBuilder: ApiURLBuilding? = nil) {
        self.apiClient = apiClient
        self.urlBuilder = urlBuilder ?? apiClient as? ApiURLBuilding
    }

    /**
     query song list
     */
    public func list(
        limit: Int = 100, offset: Int = 0, libraryScope: SynologyLibraryScope = .shared,
        artist: String? = nil, album: String? = nil, albumArtist: String? = nil,
        composer: String? = nil, genre: String? = nil, minimumRating: Int? = nil,
        includeFields: String? = "song_tag,song_audio,song_rating",
        sort: SynologySortDescriptor? = nil
    ) async throws -> SynologyPage<Song> {
        let result: SongListResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post
            ) {
                ("library", libraryScope.rawValue)
                ("limit", limit)
                ("offset", offset)
                ("artist", artist)
                ("album", album)
                ("album_artist", albumArtist)
                ("composer", composer)
                ("genre", genre)
                ("song_rating_meq", minimumRating)
                ("additional", includeFields)

                if let sort {
                    ("sort_by", sort.field)
                    ("sort_direction", sort.direction.rawValue)
                }
            }
        )
        return SynologyPage(total: result.total, items: result.songs)
    }

    /**
     build song fetch url
     */
    public func listURL(limit: Int, offset: Int, libraryScope: SynologyLibraryScope = .shared) async throws -> URL {
        guard let urlBuilder else {
            throw SynologyError.network(message: "URL builder not configured")
        }

        return try await urlBuilder.buildUrl(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post,
                sidOnQuery: true
            ) {
                ("additional", "song_tag,song_audio,song_rating")
                ("library", libraryScope.rawValue)
                ("limit", limit)
                ("offset", offset)
            }
        )
    }

    /**
     query song info
     查询歌曲信息
     - Throws: SynologyError.api(.songNotFound) when song is not found
     */
    public func getInfo(id: String) async throws -> Song {
        let result: SongInfo = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "getinfo", version: 2
            ) {
                ("id", id)
                ("additional", "song_tag,song_audio,song_rating")
            }
        )
        guard let song = result.songs.first else {
            throw SynologyError.api(code: -1, message: "query song failed")
        }

        return song
    }

    /**
     update song rating, from 1 - 5
     */
    public func setRating(id: String, rating: Int) async throws -> SongRatingUpdate {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.SONG, method: "setrating", version: 2,
            httpMethod: .post) {
                ("id", id)
                ("rating", rating)
            }

        let _: EmptyData = try await apiClient.request(api)
        return SongRatingUpdate(songID: id, rating: rating)
    }
}
