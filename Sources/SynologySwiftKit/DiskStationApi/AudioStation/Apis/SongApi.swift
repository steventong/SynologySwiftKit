//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/**
 TODO: check library: shared, persional
 */
extension AudioStationApi {
    /**
     query song list

     https://:5001/webapi/AudioStation/song.cgi

     limit: 100000
     method: list
     library: shared
     api: SYNO.AudioStation.Song
     additional: song_tag,song_audio,song_rating
     artist: 方大同
     album: 【贝壳音乐 环绕5.1】
     album_artist:
     version: 3
     sort_by: song_rating
     sort_direction: DESC
     composer: 金玟岐
     genre: 流行歌曲
     */
    public func songList(limit: Int = 100, offset: Int = 0, library: String = "shared",
                         artist: String? = nil, album: String? = nil, album_artist: String? = nil,
                         composer: String? = nil, genre: String? = nil, song_rating_meq: Int? = nil,
                         additional: String? = "song_tag,song_audio,song_rating",
                         sort: (sort_by: String, sort_direction: String)? = nil) async throws -> (total: Int, data: [Song]) {
        // 通用参数
        var parameters: [String: Any] = [
            "library": library,
            "limit": limit,
            "offset": offset,
        ]

        // 动态参数
        if let artist {
            parameters["artist"] = artist
        }

        if let album {
            parameters["album"] = album
        }

        if let album_artist {
            parameters["album_artist"] = album_artist
        }

        if let composer {
            parameters["composer"] = composer
        }

        if let genre {
            parameters["genre"] = genre
        }

        if let song_rating_meq {
            parameters["song_rating_meq"] = song_rating_meq
        }

        if let additional {
            parameters["additional"] = additional
        }

        if let sort {
            parameters["sort_by"] = sort.sort_by
            parameters["sort_direction"] = sort.sort_direction
        }

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "list", version: 3, httpMethod: .post, parameters: parameters)

        let result = try await api.requestForData(resultType: SongListResult.self)
        return (result.total, result.songs)
    }

    /**
     build song fetch url
     */
    public func songListUrl(limit: Int, offset: Int, library: String = "shared") throws -> URL {
        // 通用参数
        let parameters: [String: Any] = [
            "additional": "song_tag,song_audio,song_rating",
            "library": library,
            "limit": limit,
            "offset": offset,
        ]

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "list", version: 3, httpMethod: .post, parameters: parameters, buildSidOnQuery: true)

        return try api.assembleRequestUrl()
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
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "getinfo", version: 2, parameters: [
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
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "setrating", version: 2, httpMethod: .post, parameters: [
            "id": id,
            "rating": rating,
        ])

        try await api.request()
        return true
    }
}
