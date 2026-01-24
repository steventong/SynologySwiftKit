//
//  LyricsSearchApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func lyricsSearchSearchLyrics(title: String, artist: String) async throws -> String? {
        let lyrics: Lyrics = try await apiClient.requestForData(
            ApiEndpoint(
                api: .SYNO_AUDIO_STATION_LYRICSSEARCH, method: "searchlyrics",
                parameters: [
                    "additional": "full_lyrics",
                    "title": title,
                    "artist": artist,
                    "limit": 1,
                ]),
            resultType: Lyrics.self
        )
        return lyrics.lyrics
    }
}
