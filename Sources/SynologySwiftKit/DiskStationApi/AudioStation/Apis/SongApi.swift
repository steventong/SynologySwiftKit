//
//  SongApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// TODO: check library: shared, persional
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
    public func songList(
        limit: Int = 100, offset: Int = 0, library: String = "shared",
        artist: String? = nil, album: String? = nil, album_artist: String? = nil,
        composer: String? = nil, genre: String? = nil, song_rating_meq: Int? = nil,
        additional: String? = "song_tag,song_audio,song_rating",
        sort: (sort_by: String, sort_direction: String)? = nil
    ) async throws -> (total: Int, data: [Song]) {
        // 通用参数
        var parameters: [String: Any] = [
            "library": library,
            "limit": limit,
            "offset": offset,
        ]

        // 动态参数
        if let artist { parameters["artist"] = artist }
        if let album { parameters["album"] = album }
        if let album_artist { parameters["album_artist"] = album_artist }
        if let composer { parameters["composer"] = composer }
        if let genre { parameters["genre"] = genre }
        if let song_rating_meq { parameters["song_rating_meq"] = song_rating_meq }
        if let additional { parameters["additional"] = additional }
        if let sort {
            parameters["sort_by"] = sort.sort_by
            parameters["sort_direction"] = sort.sort_direction
        }

        let result: SongListResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: .SYNO_AUDIO_STATION_SONG, method: "list", version: 3, httpMethod: .post,
                parameters: parameters),
            resultType: SongListResult.self
        )
        return (result.total, result.songs)
    }

    /**
     build song fetch url
     */
    public func songListUrl(limit: Int, offset: Int, library: String = "shared") throws -> URL {
        let parameters: [String: Any] = [
            "additional": "song_tag,song_audio,song_rating",
            "library": library,
            "limit": limit,
            "offset": offset,
        ]

        return try apiClient.buildUrl(
            ApiEndpoint(
                api: .SYNO_AUDIO_STATION_SONG, method: "list", version: 3, httpMethod: .post,
                parameters: parameters, sidOnQuery: true)
        )
    }

    /**
     query song info
     */
    public func songGetInfo(id: String) async throws -> Song? {
        let result: SongInfo = try await apiClient.requestForData(
            ApiEndpoint(
                api: .SYNO_AUDIO_STATION_SONG, method: "getinfo", version: 2,
                parameters: [
                    "id": id,
                    "additional": "song_tag,song_audio,song_rating",
                ]),
            resultType: SongInfo.self
        )
        return result.songs.first
    }

    /**
     update song rating, from 1 - 5
     */
    public func songSetRating(id: String, rating: Int) async throws -> Bool {
        try await apiClient.request(
            ApiEndpoint(
                api: .SYNO_AUDIO_STATION_SONG, method: "setrating", version: 2, httpMethod: .post,
                parameters: [
                    "id": id,
                    "rating": rating,
                ])
        )
        return true
    }
}
