//
//  AlbumModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - Album

/// 专辑数据模型
/// Album data model
public struct Album: Decodable, Sendable {
    /// 专辑名称 / Album name
    public var name: String
    /// 艺术家名 / Artist name
    public var artist: String
    /// 专辑艺术家名 / Album artist name
    public var albumArtist: String
    /// 显示艺术家名（可能为多人合并）/ Display artist name (may combine multiple)
    public var displayArtist: String
    /// 发行年份 / Release year
    public var year: Int
    /// 额外信息（如平均评分）/ Additional info (e.g. average rating)
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

// MARK: - AlbumAdditional

/// 专辑额外信息
/// Album additional info
public struct AlbumAdditional: Decodable, Sendable {
    /// 平均评分 / Average rating
    public var avgRating: AlbumAvgRating?

    enum CodingKeys: String, CodingKey {
        case avgRating = "avg_rating"
    }
}

// MARK: - AlbumAvgRating

/// 专辑平均评分（0-5）
/// Album average rating (0-5)
public struct AlbumAvgRating: Decodable, Sendable {
    /// 评分值（0-5） / Rating value (0-5)
    public var rating: Int
}

// MARK: - AlbumListResult (Internal)

/// 专辑列表接口响应（内部使用）
/// Album list API response (internal use)
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
