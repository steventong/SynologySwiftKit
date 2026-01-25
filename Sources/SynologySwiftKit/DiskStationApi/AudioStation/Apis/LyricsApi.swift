//
//  LyricsApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

public final class LyricsApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     Get Lyrics
     */
    public func get(id: String) async throws -> Lyrics? {
        let result: LyricsResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.LYRICS, method: "getlyrics", version: 2) {
                ("id", id)
            }
        )
        return result.lyrics
    }

    /**
     Search Lyrics
     */
    public func search(title: String, artist: String, limit: Int = 10, offset: Int = 0) async throws
        -> (total: Int, data: [LyricsSearchItem])
    {
        let result: LyricsSearchResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.LYRICS_SEARCH, method: "search", version: 2) {
                ("title", title)
                ("artist", artist)
                ("limit", limit)
                ("offset", offset)
            }
        )
        return (result.total, result.items)
    }
}
