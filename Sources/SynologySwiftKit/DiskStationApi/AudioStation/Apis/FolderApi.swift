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

    /// 查询文件夹内容列表
    /// Query folder content list
    /// - Parameters:
    ///   - id: 文件夹 ID，为 nil 时查询根目录 / Folder ID, nil for root directory
    ///   - limit: 每页数量 / Page size
    ///   - offset: 起始偏移量 / Start offset
    public func list(
        id: String?,
        limit: Int = 200,
        offset: Int = 0
    ) async throws -> SynologyPage<Folder> {
        let result: FolderListResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.FOLDER, method: "list") {
                ("version", 3)
                ("id", id ?? "")
                ("library", "all")
                ("additional", "song_tag,song_audio,song_rating")
                ("limit", limit)
                ("offset", offset)
            }
        )
        return SynologyPage(total: result.total, items: result.items)
    }
}
