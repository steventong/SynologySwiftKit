//
//  FolderApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - FolderApi

/// 文件夹查询 API 客户端
/// Folder query API client
public final class FolderApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// 分页浏览目录，或递归读取目录歌曲。
    ///
    /// GET SYNO.AudioStation.Folder/list，声明版本 3；空根目录递归改用 Song/list v3 POST。
    ///
    /// 固定 library=all，展开 song_tag,song_audio,song_rating。普通浏览可混合目录与歌曲，不能将每个 item 都当成歌曲。
    ///
    /// - Parameters:
    ///   - id: 文件夹 ID；nil 或空字符串表示根目录。
    ///   - limit: 每页数量，默认 200。
    ///   - offset: 起始偏移，默认 0。
    ///   - recursive: 默认 false；指定目录时发送 true/false 字符串；空根目录递归查询 library=all 的歌曲。
    /// - Returns: SynologyPage<Folder>，普通请求映射 data.total/items；根目录递归由 Song 转为 Folder。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func list(
        id: String?,
        limit: Int = 200,
        offset: Int = 0,
        recursive: Bool = false
    ) async throws -> SynologyPage<Folder> {
        if recursive && id?.isEmpty != false {
            let songs = try await SongApi(apiClient: apiClient).list(
                limit: limit, offset: offset, libraryScope: .all
            )
            return SynologyPage(total: songs.total, items: songs.items.map {
                Folder(id: $0.id, path: $0.path, title: $0.title, type: $0.type, additional: $0.additional)
            })
        }
        let result: FolderListResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.FOLDER, method: "list", version: 3) {
                ("id", id ?? "")
                ("recursive", recursive ? "true" : "false")
                ("library", "all")
                ("additional", "song_tag,song_audio,song_rating")
                ("limit", limit)
                ("offset", offset)
            }
        )
        return SynologyPage(total: result.total, items: result.items)
    }

}
