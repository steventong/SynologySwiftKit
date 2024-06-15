//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Album: Decodable {
    public var name: String
    public var artist: String
    public var album_artist: String
    public var display_artist: String
    public var year: Int

    public var additional: AlbumAdditional?
}

public struct AlbumAdditional: Decodable {
    public var avg_rating: AlbumAvgRating?
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
