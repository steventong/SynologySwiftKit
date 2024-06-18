//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    /**
     query song list
     */
    public func songList(limit: Int, offset: Int, song_rating_meq: Int? = nil, sort: (sort_by: String, sort_direction: String)? = nil) async throws -> (total: Int, data: [Song]) {
        // 通用参数
        var parameters: [String: Any] = [
            "additional": "song_tag,song_audio,song_rating",
            "library": "all",
            "limit": limit,
            "offset": offset,
        ]

        // 动态参数
        if let song_rating_meq {
            parameters["song_rating_meq"] = song_rating_meq
        }

        if let sort {
            parameters["sort_by"] = sort.sort_by
            parameters["sort_direction"] = sort.sort_direction
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "list", version: 3, parameters: parameters)

        let result = try await api.requestForData(resultType: SongListResult.self)
        return (result.total, result.songs)
    }

    /**
     query song info

     /webapi/AudioStation/song.cgi?additional=song_rating&api=SYNO.AudioStation.Song&id=music_6910&method=getinfo&version=2
     {
         "success": true,
         "data": {
             "songs": [
                 {
                     "additional": {
                         "song_audio": {
                             "bitrate": 1536000,
                             "channel": 2,
                             "codec": "pcm_s16le",
                             "container": "wav",
                             "duration": 201,
                             "filesize": 38740388,
                             "frequency": 48000
                         },
                         "song_rating": {
                             "rating": 0
                         },
                         "song_tag": {
                             "album": "02 范特西",
                             "album_artist": "",
                             "artist": "",
                             "comment": "",
                             "composer": "",
                             "disc": 0,
                             "genre": "",
                             "track": 0,
                             "year": 0
                         }
                     },
                     "id": "music_6910",
                     "path": "/music/周杰伦/02 范特西/双截棍.wav",
                     "title": "双截棍",
                     "type": "file"
                 }
             ]
         }
     }
     */
    public func songGetInfo(id: String) async throws -> Song? {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "getinfo", version: 2, parameters: [
            "id": id,
            "additional": "song_tag,song_audio,song_rating",
        ])

        let result = try await api.requestForData(resultType: SongInfo.self)
        return result.songs.first
    }

    /**
     update song rating, from 1 - 5
     */
    public func songSetRating(id: String, rating: Int) async throws -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "setrating", version: 2, parameters: [
            "id": id,
            "rating": rating,
        ])

        return try await api.request()
    }
}
