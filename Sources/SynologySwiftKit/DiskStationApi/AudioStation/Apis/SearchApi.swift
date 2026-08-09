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

    /// 搜索歌曲、专辑、艺术家
    /// Search for songs, albums, and artists
    /// - Parameters:
    ///   - keyword: 搜索关键词 / Search keyword
    ///   - limit: 每页数量 / Page size
    ///   - offset: 起始偏移量 / Start offset
    ///   - libraryScope: 媒体库范围 / Library scope
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
