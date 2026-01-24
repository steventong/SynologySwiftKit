//
//  SearchApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/7.
//

import Foundation

extension AudioStationApi {
    public func searchList(
        keyword: String, library: String = "shared",
        limit: Int = 10, offset: Int = 0,
        additional: String = "song_tag,song_audio,song_rating",
        sort: (sort_by: String, sort_direction: String) = ("title", "ASC")
    ) async throws -> (
        albumTotal: Int, albums: [Album], artistTotal: Int, artists: [Artist], songTotal: Int,
        songs: [Song]
    ) {
        let result: SearchResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SEARCH, method: "list", httpMethod: .post,
                parameters: [
                    "keyword": keyword,
                    "library": library,
                    "limit": limit,
                    "offset": offset,
                    "sort_by": sort.sort_by,
                    "sort_direction": sort.sort_direction,
                    "additional": additional,
                ]),
            resultType: SearchResult.self
        )
        return (
            result.albumTotal, result.albums, result.artistTotal, result.artists, result.songTotal,
            result.songs
        )
    }
}
