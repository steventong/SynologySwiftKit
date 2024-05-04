//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public class AudioStationApi {
    public init() {
    }

    /**
     query song list
     */
    public func songList(limit: Int, offset: Int) async -> (total: Int, data: [Song]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "list", parameters: [
            "additional": "song_tag,song_audio,song_rating",
            "library": "all",
            "limit": limit,
            "offset": offset,
        ])

        do {
            let result = try await api.request(resultType: SongListResult.self)
            return (result.total, result.songs)
        } catch {
            Logger.error("AudioStationApi.songList error: \(error)")
        }

        return (0, [])
    }
}
