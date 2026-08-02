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
/// 封装歌词读取、搜索与写入能力。
/// Wraps lyrics retrieval, search, and persistence.
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

    /// 保存歌曲歌词
    /// Save lyrics for a song
    ///
    /// Audio Station 的标签编辑端点要求提交完整标签。本方法会先读取原始标签，
    /// 再仅替换歌词字段；封面字段保持未设置，不会修改歌曲封面。
    /// Audio Station's tag editor requires the complete tag payload. This method
    /// first loads the current tags and then replaces only the lyrics field,
    /// leaving artwork unchanged.
    ///
    /// 传入空字符串可清除歌词。
    /// Pass an empty string to remove the lyrics.
    /// - Parameters:
    ///   - lyrics: 要保存的歌词文本 / Lyrics text to save
    ///   - path: Audio Station 中的歌曲绝对路径 / Absolute song path in Audio Station
    /// - Returns: 标签编辑器的保存结果 / Tag editor save result
    public func save(_ lyrics: String, forPath path: String) async throws -> TagEditorDocument {
        try await TagEditorApi(apiClient: apiClient).saveLyrics(lyrics, forPath: path)
    }

    /// 搜索歌词
    /// Search for lyrics
    /// - Parameters:
    ///   - title: 歌曲标题 / Song title
    ///   - artist: 艺术家名 / Artist name
    ///   - limit: 返回数量限制 / Result limit
    ///   - offset: 起始偏移量 / Start offset
    public func search(title: String, artist: String, limit: Int = 10, offset: Int = 0) async throws -> SynologyPage<LyricsItem> {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.LYRICS_SEARCH, method: "searchlyrics", version: 2) {
            ("title", title)
            ("artist", artist)
            ("limit", limit)
            ("offset", offset)
            ("additional", "full_lyrics")
        }

        let result: LyricsSearchResult = try await apiClient.request(api)
        return SynologyPage(total: result.total, items: result.lyrics)
    }
}
