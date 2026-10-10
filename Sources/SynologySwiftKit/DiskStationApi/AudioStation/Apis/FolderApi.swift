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
    ///   - recursive: 由服务端展开指定文件夹的子目录歌曲（v3）；根目录递归请使用 allItems。
    ///   - limit: 每页数量 / Page size
    ///   - offset: 起始偏移量 / Start offset
    public func list(
        id: String?,
        limit: Int = 200,
        offset: Int = 0,
        recursive: Bool = false
    ) async throws -> SynologyPage<Folder> {
        let result: FolderListResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.FOLDER, method: "list") {
                ("version", 3)
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

    /// 获取完整文件夹内容。递归获取使用一次原生全量请求，不遍历子文件夹。
    /// 根目录通过 Song.list 查询所有媒体库；具体目录通过 Folder.list 的 recursive 展开。
    /// pageSize 仅用于普通（非递归）浏览。
    public func allItems(id: String?, recursive: Bool = false, pageSize: Int = 200) async throws -> [Folder] {
        try Task.checkCancellation()
        guard recursive else {
            precondition(pageSize > 0)
            return try await collectPages(id: id, recursive: false, pageSize: pageSize)
        }

        let items: [Folder]
        let total: Int
        if id?.isEmpty != false {
            let page = try await SongApi(apiClient: apiClient).list(limit: -1, offset: 0, libraryScope: .all)
            total = page.total
            items = page.items.map {
                Folder(id: $0.id, path: $0.path, title: $0.title, type: $0.type, additional: $0.additional)
            }
        } else {
            let page = try await list(id: id, limit: -1, offset: 0, recursive: true)
            total = page.total
            items = page.items
        }
        try Task.checkCancellation()
        guard items.count >= total else {
            throw SynologyError.api(code: -1, message: "Audio Station returned an incomplete song list (\(items.count)/\(total)).")
        }
        return items
    }

    private func collectPages(id: String?, recursive: Bool, pageSize: Int) async throws -> [Folder] {
        var items: [Folder] = []
        var offset = 0
        while true {
            try Task.checkCancellation()
            let page = try await list(id: id, limit: pageSize, offset: offset, recursive: recursive)
            try Task.checkCancellation()
            items += page.items
            offset += page.items.count
            if page.items.isEmpty || offset >= page.total { return items }
        }
    }

}
