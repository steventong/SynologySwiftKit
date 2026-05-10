//
//  SearchModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/7.
//

import Foundation

// MARK: - AudioStationSearchResults

/// AudioStation 搜索结果（聚合专辑、艺术家、歌曲）
/// AudioStation search results (aggregated albums, artists, songs)
public struct AudioStationSearchResults: Sendable {
    /// 匹配的专辑分页结果 / Matching albums paged result
    public let albums: SynologyPage<Album>
    /// 匹配的艺术家分页结果 / Matching artists paged result
    public let artists: SynologyPage<Artist>
    /// 匹配的歌曲分页结果 / Matching songs paged result
    public let songs: SynologyPage<Song>

    public init(albums: SynologyPage<Album>, artists: SynologyPage<Artist>, songs: SynologyPage<Song>) {
        self.albums = albums
        self.artists = artists
        self.songs = songs
    }
}

// MARK: - SearchResult (Internal)

/// 搜索接口原始响应（内部使用）
/// Raw search API response (internal use)
struct SearchResult: Decodable, Sendable {
    /// 专辑总数 / Total album count
    var albumTotal: Int
    /// 专辑列表 / Album list
    var albums: [Album]

    /// 艺术家总数 / Total artist count
    var artistTotal: Int
    /// 艺术家列表 / Artist list
    var artists: [Artist]

    /// 歌曲总数 / Total song count
    var songTotal: Int
    /// 歌曲列表 / Song list
    var songs: [Song]
}
