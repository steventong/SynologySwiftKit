//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func lyricsGetLyrics(id: String) async throws -> String? {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_LYRICS, method: "getlyrics", version: 1, parameters: [
            "library": "all",
            "id": id,
            "version": 1,
        ])

        do {
            let lyrics = try await api.requestForData(resultType: Lyrics.self)
            return lyrics.lyrics
        } catch {
            Logger.error("AudioStationApi.LyricsApi.lyricsGetLyrics error: \(error)")
        }

        return nil
    }
}
