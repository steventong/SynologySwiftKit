//

//
//
//  Created by Steven on 2024/5/4.
//

import Foundation

/// Audio Station 对单首歌曲暴露的功能能力。
///
/// 默认值表示普通音乐源支持全部编辑能力；Audio Station 的歌曲模型会根据
/// 虚拟歌曲 ID、资源类型和文件扩展名覆盖实际能力。
public struct SongCapabilities: Codable, Equatable, Sendable {
    public var supportsMetadataEditing: Bool
    public var supportsLyricsMatching: Bool
    public var supportsLyricsSaving: Bool
    public var supportsArtworkMatching: Bool
    public var supportsArtworkSaving: Bool

    public init(
        supportsMetadataEditing: Bool = true,
        supportsLyricsMatching: Bool = true,
        supportsLyricsSaving: Bool = true,
        supportsArtworkMatching: Bool = true,
        supportsArtworkSaving: Bool = true
    ) {
        self.supportsMetadataEditing = supportsMetadataEditing
        self.supportsLyricsMatching = supportsLyricsMatching
        self.supportsLyricsSaving = supportsLyricsSaving
        self.supportsArtworkMatching = supportsArtworkMatching
        self.supportsArtworkSaving = supportsArtworkSaving
    }

    public static let allSupported = SongCapabilities()
}

enum AudioStationSongCapabilitiesResolver {
    private static let virtualIDPrefixes = ["music_v_", "music_p_v_"]
    private static let tagEditableFileExtensions: Set<String> = [
        "mp3", "ogg", "m4a", "m4p", "flac", "aiff", "aif", "m4b",
    ]

    static func resolve(id: String, type: String, path: String) -> SongCapabilities {
        let isVirtual = virtualIDPrefixes.contains { id.hasPrefix($0) }
        let isLocalFile = type.caseInsensitiveCompare("file") == .orderedSame
            && !path.lowercased().hasPrefix("http")
        let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        let supportsTagEditing = isLocalFile
            && !isVirtual
            && tagEditableFileExtensions.contains(fileExtension)

        return SongCapabilities(
            supportsMetadataEditing: supportsTagEditing,
            supportsLyricsMatching: true,
            supportsLyricsSaving: supportsTagEditing,
            supportsArtworkMatching: true,
            supportsArtworkSaving: supportsTagEditing
        )
    }
}

/// {
///         "path": "\/music\/五月天\/五月天专辑\/2007.04-Enrich Your Life\/CDImage.ape",
///         "id": "music_v_6503",
///         "additional": {
///           "song_tag": {
///             "artist": "五月天",
///             "disc": 0,
///             "album_artist": "五月天",
///             "track": 6,
///             "album": "Enrich Your Life让我照顾你",
///             "year": 0,
///             "comment": "21:22:53\/volume1\/music\/五月天\/五月天专辑\/2007.04-Enrich Your Life\/CDImage.cue",
///             "genre": "",
///             "composer": ""
///           },
///           "song_rating": {
///             "rating": 0
///           },
///           "song_audio": {
///             "channel": 2,
///             "filesize": 0,
///             "frequency": 44100,
///             "codec": "ape",
///             "container": "ape",
///             "duration": 166,
///             "bitrate": 0
///           }
///         },
///         "title": "Enrich Your Life让我照顾你(演奏版)",
///         "type": "file"
///       }
public struct Song: Decodable, Encodable, Sendable {
    public var id: String
    public var title: String
    public var type: String
    public var path: String

    public var additional: SongAdditional?

    public var audio: SongAudio? {
        additional?.songAudio
    }

    public var rating: SongRating? {
        additional?.songRating
    }

    public var tag: SongTag? {
        additional?.songTag
    }

    /// 与 Audio Station Web UI `isTagEditableMusic` 保持一致的能力判断。
    public var capabilities: SongCapabilities {
        AudioStationSongCapabilitiesResolver.resolve(
            id: id,
            type: type,
            path: path
        )
    }
}

public struct SongAdditional: Decodable, Encodable, Sendable {
    public var songAudio: SongAudio?
    public var songRating: SongRating?
    public var songTag: SongTag?

    enum CodingKeys: String, CodingKey {
        case songAudio = "song_audio"
        case songRating = "song_rating"
        case songTag = "song_tag"
    }
}

public struct SongAudio: Decodable, Encodable, Sendable {
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

public struct SongRating: Decodable, Encodable, Sendable {
    // 评分 0-5
    public var rating: Int
}

public struct SongTag: Decodable, Encodable, Sendable {
    // 专辑
    public var album: String
    // 专辑艺人
    public var albumArtist: String
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

    enum CodingKeys: String, CodingKey {
        case album
        case albumArtist = "album_artist"
        case artist
        case comment
        case composer
        case disc
        case genre
        case track
        case year
    }
}

struct SongListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let songs: [Song]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case songs
    }
}


public enum SongStreamQuality: String, Sendable {
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
            192000
        case .LOW:
            128000
        case .ORIGINAL:
            nil
        }
    }
}

public struct SongPlaybackSource: Sendable {
    public let id: String
    public let path: String
    public let bitrate: Int
    public let frequency: Int
    public let fileExtension: String

    public init(id: String, path: String, bitrate: Int, frequency: Int, fileExtension: String = ".mp3") {
        self.id = id
        self.path = path
        self.bitrate = bitrate
        self.frequency = frequency
        self.fileExtension = fileExtension
    }
}

public struct SongRatingUpdate: Sendable {
    public let songID: String
    public let rating: Int

    public init(songID: String, rating: Int) {
        self.songID = songID
        self.rating = rating
    }
}

struct SongInfo: Decodable, Sendable {
    /**
     songs
     */
    var songs: [Song]
}
