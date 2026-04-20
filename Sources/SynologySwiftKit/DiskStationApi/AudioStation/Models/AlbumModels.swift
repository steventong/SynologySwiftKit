//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Album: Decodable, Sendable {
    public var name: String
    public var artist: String
    public var albumArtist: String
    public var displayArtist: String
    public var year: Int

    public var additional: AlbumAdditional?

    enum CodingKeys: String, CodingKey {
        case name
        case artist
        case albumArtist = "album_artist"
        case displayArtist = "display_artist"
        case year
        case additional
    }
}

public struct AlbumAdditional: Decodable, Sendable {
    public var avgRating: AlbumAvgRating?

    enum CodingKeys: String, CodingKey {
        case avgRating = "avg_rating"
    }
}

public struct AlbumAvgRating: Decodable, Sendable {
    // 评分 0-5
    public var rating: Int
}

struct AlbumListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let albums: [Album]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case albums
    }
}

