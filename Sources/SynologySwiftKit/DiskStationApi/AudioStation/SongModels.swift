//
//  File.swift
//
//
//  Created by Steven on 2024/5/4.
//

import Foundation

/**

 {
         "path": "\/music\/五月天\/五月天专辑\/2007.04-Enrich Your Life\/CDImage.ape",
         "id": "music_v_6503",
         "additional": {
           "song_tag": {
             "artist": "五月天",
             "disc": 0,
             "album_artist": "五月天",
             "track": 6,
             "album": "Enrich Your Life让我照顾你",
             "year": 0,
             "comment": "21:22:53\/volume1\/music\/五月天\/五月天专辑\/2007.04-Enrich Your Life\/CDImage.cue",
             "genre": "",
             "composer": ""
           },
           "song_rating": {
             "rating": 0
           },
           "song_audio": {
             "channel": 2,
             "filesize": 0,
             "frequency": 44100,
             "codec": "ape",
             "container": "ape",
             "duration": 166,
             "bitrate": 0
           }
         },
         "title": "Enrich Your Life让我照顾你(演奏版)",
         "type": "file"
       }
 */
struct Song: Decodable {
    var id: String
    var title: String
    var type: String
    var path: String

    var additional: SongAdditional?
}

struct SongAdditional: Decodable {
    var song_audio: SongAudio?
    var song_rating: SongRating?
    var song_tag: SongTag?
}

struct SongAudio: Decodable {
    var bitrate: Int
    var channel: Int
    var codec: String
    var container: String
    var duration: Double
    var filesize: Int
    var frequency: Int
}

struct SongRating: Decodable {
    var rating: Int
}

struct SongTag: Decodable {
    var album: String
    var album_artist: String
    var artist: String
    var comment: String
    var composer: String
    var disc: Int
    var genre: String
    var track: Int
    var year: Int
}

public struct SongListResult: Decodable {
    var offset: Int
    var total: Int

    var songs: [Song]
}
