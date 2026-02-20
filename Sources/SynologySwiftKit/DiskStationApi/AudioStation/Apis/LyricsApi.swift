//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func lyricsGetLyrics(id: String) async throws -> String? {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_LYRICS, method: "getlyrics", version: 1, parameters: [
            "library": "all",
            "id": id,
        ])

        let lyrics = try await api.requestForData(resultType: Lyrics.self)
        return lyrics.lyrics
    }
}
