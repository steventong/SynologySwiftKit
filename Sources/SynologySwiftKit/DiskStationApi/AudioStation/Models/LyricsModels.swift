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
public struct LyricsResult: Decodable, Sendable {
    
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

public struct LyricsSearchItem: Decodable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let preview: String?
}

public struct LyricsSearchResult: Decodable, Sendable {
    public let total: Int
    public let items: [LyricsSearchItem]
}
