//

//  SynologySwiftKit
//
//  Created by Steven on 2024/10/7.
//

import Foundation

public struct AudioStationSearchResults: Sendable {
    public let albums: SynologyPage<Album>
    public let artists: SynologyPage<Artist>
    public let songs: SynologyPage<Song>

    public init(albums: SynologyPage<Album>, artists: SynologyPage<Artist>, songs: SynologyPage<Song>) {
        self.albums = albums
        self.artists = artists
        self.songs = songs
    }
}

struct SearchResult: Decodable, Sendable {
    /**
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
     */

    var albumTotal: Int
    var albums: [Album]

    var artistTotal: Int
    var artists: [Artist]

    var songTotal: Int
    var songs: [Song]
}
