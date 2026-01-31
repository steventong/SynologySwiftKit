//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Lyrics: Decodable, Sendable {
    public var lyrics: String
}

public struct LyricsResult: Decodable, Sendable {
    public let lyrics: Lyrics?
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
