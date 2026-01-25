//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Lyrics: Decodable {
    public var lyrics: String
}

public struct LyricsResult: Decodable {
    public let lyrics: Lyrics?
}

public struct LyricsSearchItem: Decodable {
    public let id: String
    public let title: String
    public let artist: String
    public let preview: String?
}

public struct LyricsSearchResult: Decodable {
    public let total: Int
    public let items: [LyricsSearchItem]
}
