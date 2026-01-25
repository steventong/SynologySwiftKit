//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Album: Decodable {
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

public struct AlbumAdditional: Decodable {
    public var avgRating: AlbumAvgRating?

    enum CodingKeys: String, CodingKey {
        case avgRating = "avg_rating"
    }
}

public struct AlbumAvgRating: Decodable {
    // 评分 0-5
    public var rating: Int
}

public struct AlbumListResult: Decodable {
    public var offset: Int
    public var total: Int

    public var albums: [Album]
}
