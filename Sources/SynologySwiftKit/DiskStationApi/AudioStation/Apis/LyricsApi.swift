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
     获取歌词
     - Throws: SynologyError.network(.responseEmpty) when lyrics content is empty or not found
     */
    public func get(id: String) async throws -> String {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.LYRICS, method: "getlyrics", version: 2) {
            ("id", id)
        }

        let result: LyricsResult = try await apiClient.request(api)
        guard let lyrics = result.lyrics, !lyrics.lyrics.isEmpty else {
            throw SynologyError.api(.lyricsNotFound)
        }
        return lyrics.lyrics
    }

    /**
     Search Lyrics
     */
    public func search(title: String, artist: String, limit: Int = 10, offset: Int = 0) async throws -> (total: Int, data: [LyricsItem]) {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.LYRICS_SEARCH, method: "searchlyrics", version: 1) {
            ("title", title)
            ("artist", artist)
            ("limit", limit)
            ("additional", "full_lyrics")
        }

        let result: LyricsSearchResult = try await apiClient.request(api)
        return (result.total, result.items)
    }
}
