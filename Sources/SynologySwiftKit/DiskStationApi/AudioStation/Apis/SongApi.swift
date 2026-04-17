//
//  SongApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

public final class SongApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     query song list
     */
    public func list(
        limit: Int = 100, offset: Int = 0, library: String = "shared",
        artist: String? = nil, album: String? = nil, album_artist: String? = nil,
        composer: String? = nil, genre: String? = nil, song_rating_meq: Int? = nil,
        additional: String? = "song_tag,song_audio,song_rating",
        sort: (sort_by: String, sort_direction: String)? = nil
    ) async throws -> (total: Int, data: [Song]) {
        let result: SongListResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post
            ) {
                ("library", library)
                ("limit", limit)
                ("offset", offset)
                ("artist", artist)
                ("album", album)
                ("album_artist", album_artist)
                ("composer", composer)
                ("genre", genre)
                ("song_rating_meq", song_rating_meq)
                ("additional", additional)

                if let sort {
                    ("sort_by", sort.sort_by)
                    ("sort_direction", sort.sort_direction)
                }
            }
        )
        return (result.total, result.songs)
    }

    /**
     build song fetch url
     */
    public func listUrl(limit: Int, offset: Int, library: String = "shared") async throws -> URL {
        try await apiClient.buildUrl(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post,
                sidOnQuery: true
            ) {
                ("additional", "song_tag,song_audio,song_rating")
                ("library", library)
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
    public func setRating(id: String, rating: Int) async throws -> Bool {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.SONG, method: "setrating", version: 2,
            httpMethod: .post) {
                ("id", id)
                ("rating", rating)
            }

        let _: EmptyData = try await apiClient.request(api)
        return true
    }
}
