//
//  LyricsApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

// MARK: - LyricsApi

/// 歌词 API 客户端
/// Lyrics API client
///
/// 封装 `SYNO.AudioStation.Lyrics` 和 `SYNO.AudioStation.Lyrics.Search` 接口。
/// Wraps `SYNO.AudioStation.Lyrics` and `SYNO.AudioStation.Lyrics.Search`.
public final class LyricsApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// 获取歌曲歌词
    /// Get lyrics for a song
    /// - Parameter id: 歌曲 ID / Song ID
    /// - Throws: `SynologyError.api(code: 404)` 当歌词不存在时 / When lyrics not found
    public func get(id: String) async throws -> String {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.LYRICS, method: "getlyrics", version: 2) {
            ("id", id)
        }

        let result: LyricsResult = try await apiClient.request(api)
        guard let lyrics = result.lyrics, !lyrics.lyrics.isEmpty else {
            throw SynologyError.api(code: 404, message: "lyrics not found")
        }
        return lyrics.lyrics
    }

    /// 搜索歌词
    /// Search for lyrics
    /// - Parameters:
    ///   - title: 歌曲标题 / Song title
    ///   - artist: 艺术家名 / Artist name
    ///   - limit: 返回数量限制 / Result limit
    ///   - offset: 起始偏移量 / Start offset
    public func search(title: String, artist: String, limit: Int = 10, offset: Int = 0) async throws -> SynologyPage<LyricsItem> {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.LYRICS_SEARCH, method: "searchlyrics", version: 1) {
            ("title", title)
            ("artist", artist)
            ("limit", limit)
            ("additional", "full_lyrics")
        }

        let result: LyricsSearchResult = try await apiClient.request(api)
        return SynologyPage(total: result.total, items: result.items)
    }
}
