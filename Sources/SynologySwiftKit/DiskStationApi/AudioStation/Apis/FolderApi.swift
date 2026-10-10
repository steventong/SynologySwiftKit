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

    /// 获取完整文件夹内容。根目录是索引目录入口，须先列出入口再分别递归查询。
    /// `recursive` 只对实际文件夹 ID 使用服务端展开；任一页失败时不返回部分结果。
    public func allItems(id: String?, recursive: Bool = false, pageSize: Int = 200) async throws -> [Folder] {
        precondition(pageSize > 0)
        let isRoot = id?.isEmpty != false
        let items = try await collectPages(id: id, recursive: recursive && !isRoot, pageSize: pageSize)
        guard recursive && isRoot else { return items }

        var songs = items.filter { $0.type == "file" }
        var visited = Set<String>()
        for folder in items where folder.type == "folder" && !folder.id.isEmpty {
            guard visited.insert(folder.id).inserted else { continue }
            songs += try await collectPages(id: folder.id, recursive: true, pageSize: pageSize)
                .filter { $0.type == "file" }
        }
        try Task.checkCancellation()
        var seen = Set<String>()
        return songs.filter { seen.insert($0.id).inserted }
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
