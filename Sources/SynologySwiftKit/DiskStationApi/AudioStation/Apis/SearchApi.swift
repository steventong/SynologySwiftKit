//
//  SearchApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - SearchApi

/// 搜索 API 客户端
/// Search API client
///
/// 封装 `SYNO.AudioStation.Search` 接口，支持关键词搜索歌曲/专辑/艺术家。
/// Wraps `SYNO.AudioStation.Search`; supports keyword search for songs, albums, and artists.
public final class SearchApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// 同时搜索歌曲、专辑和艺术家。
    ///
    /// POST SYNO.AudioStation.Search/list，声明版本 1。
    ///
    /// 不能把三个分类的 total 视为一份统一分页总数。
    ///
    /// - Parameters:
    ///   - keyword: 搜索关键词。
    ///   - limit: 各类结果请求的数量限制，默认 1000。
    ///   - offset: 起始偏移，默认 0。
    ///   - libraryScope: library，必须指定。
    ///   - includeFields: additional；nil 时省略，歌曲详情可用 song_tag,song_audio,song_rating。
    ///   - sort: sort_by/sort_direction；nil 时省略。
    /// - Returns: AudioStationSearchResults，albums/artists/songs 各有独立 total/items。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func list(
        keyword: String, limit: Int = 1000, offset: Int = 0,
        libraryScope: SynologyLibraryScope,
        includeFields: String? = nil,
        sort: SynologySortDescriptor? = nil
    ) async throws -> AudioStationSearchResults {
        let result: SearchResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SEARCH, method: "list", version: 1, httpMethod: .post
            ) {
                ("keyword", keyword)
                ("limit", limit)
                ("offset", offset)
                ("library", libraryScope.rawValue)
                ("additional", includeFields)
                if let sort {
                    ("sort_by", sort.field)
                    ("sort_direction", sort.direction.rawValue)
                }
            }
        )
        return AudioStationSearchResults(
            albums: SynologyPage(total: result.albumTotal, items: result.albums),
            artists: SynologyPage(total: result.artistTotal, items: result.artists),
            songs: SynologyPage(total: result.songTotal, items: result.songs)
        )
    }
}
