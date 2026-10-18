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

    /// 读取歌曲歌词。
    ///
    /// GET SYNO.AudioStation.Lyrics/getlyrics，声明版本 2。
    ///
    /// - Parameters:
    ///   - id: 歌曲 ID。
    /// - Returns: 非空歌词字符串；解码支持 data.lyrics 为字符串或含 lyrics 的对象。
    /// - Throws: 请求错误；缺失或空歌词抛出 Kit 生成的 SynologyError.api(code: 404)，不一定是服务端返回的 404。
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

    /// 先读取完整标签，再替换歌词并保存。
    ///
    /// POST tagEditorUI/tag_editor.cgi，依次 action=load/apply；不调用 Lyrics/setlyrics。
    ///
    /// 保留其他标签，显式提交 coverType=original_image 保留封面。要求文件可编辑且当前用户有标签编辑权限。
    ///
    /// - Parameters:
    ///   - lyrics: 完整歌词文本；空字符串清除歌词。
    ///   - path: NAS 上歌曲的绝对路径，不是歌曲 ID。
    /// - Returns: TagEditorDocument；详见 TagEditorApi 的结果限制。
    /// - Throws: 请求错误；读取失败、无可用文件或 CGI success=false 时抛出 SynologyError.api(code: -1)。
    public func save(_ lyrics: String, forPath path: String) async throws -> TagEditorDocument {
        try await TagEditorApi(apiClient: apiClient).saveLyrics(lyrics, forPath: path)
    }

    /// 通过服务端歌词插件搜索歌词。
    ///
    /// GET SYNO.AudioStation.LyricsSearch/searchlyrics，声明版本 2。
    ///
    /// 固定 additional=full_lyrics；没有公开 offset、sharing_id 或 song_id 参数。插件可用性由 NAS 决定。
    ///
    /// - Parameters:
    ///   - title: 歌曲标题。
    ///   - artist: 艺术家名称。
    ///   - limit: 最多请求的结果数，默认 10。
    /// - Returns: SynologyPage<LyricsItem>，来自 data.total/lyrics。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func search(title: String, artist: String, limit: Int = 10) async throws -> SynologyPage<LyricsItem> {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.LYRICS_SEARCH, method: "searchlyrics", version: 2) {
            ("title", title)
            ("artist", artist)
            ("limit", limit)
            ("additional", "full_lyrics")
        }

        let result: LyricsSearchResult = try await apiClient.request(api)
        return SynologyPage(total: result.total, items: result.lyrics)
    }
}
