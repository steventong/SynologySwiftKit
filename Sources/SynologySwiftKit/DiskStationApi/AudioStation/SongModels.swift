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
public struct Song: Decodable, Encodable {
    public var id: String
    public var title: String
    public var type: String
    public var path: String

    var additional: SongAdditional?

    public var audio: SongAudio? {
        additional?.song_audio
    }

    public var rating: SongRating? {
        additional?.song_rating
    }

    public var tag: SongTag? {
        additional?.song_tag
    }
}

struct SongAdditional: Decodable, Encodable {
    var song_audio: SongAudio?
    var song_rating: SongRating?
    var song_tag: SongTag?
}

public struct SongAudio: Decodable, Encodable {
    public var bitrate: Int
    public var channel: Int
    public var codec: String
    public var container: String
    public var duration: Double
    public var filesize: Int
    public var frequency: Int
}

public struct SongRating: Decodable, Encodable {
    public var rating: Int
}

public struct SongTag: Decodable, Encodable {
    public var album: String
    public var album_artist: String
    public var artist: String
    public var comment: String
    public var composer: String
    public var disc: Int
    public var genre: String
    public var track: Int
    public var year: Int
}

public struct SongListResult: Decodable, Encodable {
    public var offset: Int
    public var total: Int

    public var songs: [Song]
}

public enum SongStreamQuality: String {
    case LOW
    case MEDIUM
    case HIGH
    case ORIGINAL

    var format: String {
        switch self {
        case .HIGH:
            "wav"
        case .MEDIUM:
            "mp3"
        case .LOW:
            "mp3"
        case .ORIGINAL:
            "mp3"
        }
    }

    var bitrate: Int? {
        switch self {
        case .HIGH:
            320000
        case .MEDIUM:
            256000
        case .LOW:
            128000
        case .ORIGINAL:
            nil
        }
    }
}

public struct SongInfo: Decodable {
    /**
     songs
     */
    var songs: [Song]
    
}
