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

    public var additional: SongAdditional?

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

public struct SongAdditional: Decodable, Encodable {
    public var song_audio: SongAudio?
    public var song_rating: SongRating?
    public var song_tag: SongTag?
}

public struct SongAudio: Decodable, Encodable {
    // 码率 bps
    public var bitrate: Int
    // 声道数
    public var channel: Int
    // 文件类型
    public var codec: String
    // 文件类型
    public var container: String
    // 时长
    public var duration: Double
    // 文件大小 b
    public var filesize: Int64
    // 取样率 hz
    public var frequency: Int
}

public struct SongRating: Decodable, Encodable {
    // 评分 0-5
    public var rating: Int
}

public struct SongTag: Decodable, Encodable {
    // 专辑
    public var album: String
    // 专辑艺人
    public var album_artist: String
    // 艺人
    public var artist: String
    // 备注、注解
    public var comment: String
    // 作曲者
    public var composer: String
    // 光盘 #
    public var disc: Int
    // 类型
    public var genre: String
    // 轨道 #
    public var track: Int
    // 年份
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
            "mp3"
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
