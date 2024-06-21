//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func lyricsSearchSearchLyrics(title: String, artist: String) async throws -> String? {
        let api = try SynoDiskStationApi(api: .SYNO_AUDIO_STATION_LYRICSSEARCH, method: "searchlyrics", version: 1, parameters: [
            "additional": "full_lyrics",
            "title": title,
            "artist": artist,
            "limit": 1,
        ])

        let lyrics = try await api.requestForData(resultType: Lyrics.self)
        return lyrics.lyrics
    }
}
