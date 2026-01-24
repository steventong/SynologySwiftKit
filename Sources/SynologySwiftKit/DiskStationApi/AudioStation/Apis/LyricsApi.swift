//
//  LyricsApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func lyricsGetLyrics(id: String) async throws -> String? {
        let lyrics: Lyrics = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.lyrics, method: "getlyrics",
                parameters: [
                    "library": "all",
                    "id": id,
                ]),
            resultType: Lyrics.self
        )
        return lyrics.lyrics
    }
}
