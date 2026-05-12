//
//  SongApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

// MARK: - SongApi

/// 歌曲查询 API 客户端
/// Song query API client
///
/// 封装 `SYNO.AudioStation.Song` 接口，支持列表查询、单曲信息获取和评分更新。
/// Wraps `SYNO.AudioStation.Song`; supports list query, single song info, and rating update.
public final class SongApi {
    private let apiClient: ApiRequestSending
    private let urlBuilder: ApiURLBuilding?

    init(apiClient: ApiRequestSending, urlBuilder: ApiURLBuilding? = nil) {
        self.apiClient = apiClient
        self.urlBuilder = urlBuilder ?? apiClient as? ApiURLBuilding
    }

    /// 查询歌曲列表
    /// Query song list
    /// - Parameters:
    ///   - limit: 每页数量 / Page size
    ///   - offset: 起始偏移量 / Start offset
    ///   - libraryScope: 媒体库范围 / Library scope
    ///   - artist: 按艺术家过滤 / Filter by artist
    ///   - album: 按专辑过滤 / Filter by album
    ///   - albumArtist: 按专辑艺术家过滤 / Filter by album artist
    ///   - composer: 按作曲家过滤 / Filter by composer
    ///   - genre: 按流派过滤 / Filter by genre
    ///   - minimumRating: 最低评分过滤 / Minimum rating filter
    ///   - includeFields: 额外字段（默认包含标签/音频/评分）/ Extra fields (default: tag/audio/rating)
    ///   - sort: 排序描述符 / Sort descriptor
    public func list(
        limit: Int = 100, offset: Int = 0, libraryScope: SynologyLibraryScope = .shared,
        artist: String? = nil, album: String? = nil, albumArtist: String? = nil,
        composer: String? = nil, genre: String? = nil, minimumRating: Int? = nil,
        includeFields: String? = "song_tag,song_audio,song_rating",
        sort: SynologySortDescriptor? = nil
    ) async throws -> SynologyPage<Song> {
        let result: SongListResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post
            ) {
                ("library", libraryScope.rawValue)
                ("limit", limit)
                ("offset", offset)
                ("artist", artist)
                ("album", album)
                ("album_artist", albumArtist)
                ("composer", composer)
                ("genre", genre)
                ("song_rating_meq", minimumRating)
                ("additional", includeFields)

                if let sort {
                    ("sort_by", sort.field)
                    ("sort_direction", sort.direction.rawValue)
                }
            }
        )
        return SynologyPage(total: result.total, items: result.songs)
    }

    /// 构建歌曲列表获取请求的 URL（用于 WKWebView / AVPlayer 等无法注入 Header 的场景）
    /// Build the URL for a song list request (for WKWebView/AVPlayer where headers cannot be injected)
    public func listURL(limit: Int, offset: Int, libraryScope: SynologyLibraryScope = .shared) async throws -> URL {
        guard let urlBuilder else {
            throw SynologyError.network(message: "URL builder not configured")
        }

        return try await urlBuilder.buildUrl(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post,
                sidOnQuery: true
            ) {
                ("additional", "song_tag,song_audio,song_rating")
                ("library", libraryScope.rawValue)
                ("limit", limit)
                ("offset", offset)
            }
        )
    }

    /// 查询单首歌曲详细信息
    /// Query detailed info for a single song
    /// - Parameter id: 歌曲 ID / Song ID
    /// - Throws: `SynologyError.api` 当歌曲不存在时 / When song is not found
    public func getInfo(id: String) async throws -> Song {
        let result: SongInfo = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "getinfo", version: 2
            ) {
                ("id", id)
                ("additional", "song_tag,song_audio,song_rating")
            }
        )
        guard let song = result.songs.first else {
            throw SynologyError.api(code: -1, message: "query song failed")
        }

        return song
    }

    /// 更新歌曲评分（1 - 5 星）
    /// Update song rating (1 - 5 stars)
    /// - Parameters:
    ///   - id: 歌曲 ID / Song ID
    ///   - rating: 评分（1-5）/ Rating (1-5)
    public func setRating(id: String, rating: Int) async throws -> SongRatingUpdate {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.SONG, method: "setrating", version: 2,
            httpMethod: .post) {
                ("id", id)
                ("rating", rating)
            }

        let _: EmptyData = try await apiClient.request(api)
        return SongRatingUpdate(songID: id, rating: rating)
    }
}
