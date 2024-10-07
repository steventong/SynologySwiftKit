//
//  File.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/7.
//

import Foundation

extension AudioStationApi {
    /**
     https://:5001/webapi/AudioStation/search.cgi

     limit: 10
     api: SYNO.AudioStation.Search
     method: list
     library: shared
     additional: song_tag,song_audio,song_rating
     version: 1
     keyword: 风
     sort_by: title
     sort_direction: ASC

     {
         "data": {
             "albumTotal": 15,
             "albums": [
                 {
                     "album_artist": "谭咏麟",
                     "artist": "",
                     "display_artist": "谭咏麟",
                     "name": "Lorelei 暴风女神",
                     "year": 2015
                 }
             ],
             "artistTotal": 22,
             "artists": [
                 {
                     "name": "P.W.W.画风风"
                 }
             ],
             "songTotal": 901,
             "songs": [
                 {
                     "additional": {
                         "song_audio": {
                             "bitrate": 786000,
                             "channel": 2,
                             "codec": "flac",
                             "container": "flac",
                             "duration": 228,
                             "filesize": 22606922,
                             "frequency": 44100
                         },
                         "song_tag": {
                             "album": "One芳 新歌+精选",
                             "album_artist": "万芳",
                             "artist": "万芳",
                             "comment": "",
                             "composer": "",
                             "disc": 0,
                             "genre": "",
                             "track": 25,
                             "year": 2005
                         }
                     },
                     "id": "music_355928",
                     "path": "/music/其他艺人/万芳/万芳 - One芳 新歌+精选/万芳 - 听风的歌.flac",
                     "title": "听风的歌",
                     "type": "file"
                 }
             ]
         },
         "success": true
     }
     */
    public func searchList(keyword: String, library: String = "shared",
                           limit: Int = 10, offset: Int = 0,
                           sort: (sort_by: String, sort_direction: String) = ("title", "ASC")) async throws -> (albumTotal: Int, albums: [Album], artistTotal: Int, artists: [Artist], songTotal: Int, songs: [Song]) {
        let parameters: [String: Any] = [
            "keyword": keyword,
            "library": library,
            "limit": limit,
            "offset": offset,
            "sort_by": sort.sort_by,
            "sort_direction": sort.sort_direction,
            "additional": "song_tag,song_audio,song_rating",
//            "additional": "songs_song_tag,songs_song_audio,songs_song_rating,sharing_info",
        ]

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_SEARCH, method: "list", version: 1, httpMethod: .post, parameters: parameters)

        let result = try await api.requestForData(resultType: SearchResult.self)
        return (result.albumTotal, result.albums, result.artistTotal, result.artists, result.songTotal, result.songs)
    }
}
