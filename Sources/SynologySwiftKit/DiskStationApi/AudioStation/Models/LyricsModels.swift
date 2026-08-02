//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Lyrics: Decodable, Sendable {
    public var lyrics: String
}

/// 歌词结果（支持两种格式：字符串或嵌套对象）
/// Lyrics result (supports both formats: string or nested object)
struct LyricsResult: Decodable, Sendable {
    public let lyrics: Lyrics?

    private enum CodingKeys: String, CodingKey {
        case lyrics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 尝试解码为字符串
        // Try to decode as string
        if let lyricsString = try? container.decode(String.self, forKey: .lyrics) {
            lyrics = Lyrics(lyrics: lyricsString)
        }
        // 尝试解码为嵌套对象
        // Try to decode as nested object
        else if let lyricsObject = try? container.decode(Lyrics.self, forKey: .lyrics) {
            lyrics = lyricsObject
        } else {
            lyrics = nil
        }
    }
}

public struct LyricsItem: Decodable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let preview: String?
    public let plugin: String?
    public let fullLyrics: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case preview = "partial_lyrics"
        case plugin
        case additional
    }

    private enum AdditionalCodingKeys: String, CodingKey {
        case fullLyrics = "full_lyrics"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        preview = try container.decodeIfPresent(String.self, forKey: .preview)
        plugin = try container.decodeIfPresent(String.self, forKey: .plugin)

        let additional = try container.nestedContainer(
            keyedBy: AdditionalCodingKeys.self,
            forKey: .additional
        )
        fullLyrics = try additional.decode(String.self, forKey: .fullLyrics)
    }
}

struct LyricsSearchResult: Decodable, Sendable {
    public let total: Int
    public let lyrics: [LyricsItem]
}
