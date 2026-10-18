//
//  GenreApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - GenreApi

/// 流派查询 API 客户端
/// Genre query API client
public final class GenreApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// 分页查询流派。
    ///
    /// POST SYNO.AudioStation.Genre/list，声明版本 3。
    ///
    /// additional 不会让 Swift 模型自动增加字段；可读取内容以对应 Models 文件为准。
    ///
    /// - Parameters:
    ///   - limit: 每页数量，默认 1000；原样发送，不在本地限制范围。
    ///   - offset: 起始偏移，默认 0。
    ///   - libraryScope: library，默认 shared；可选 personal/all。
    ///   - includeFields: additional，逗号分隔展开字段，例如 avg_rating；nil 时不发送。
    ///   - filter: 原样发送的服务端过滤字符串；nil 时省略。
    ///   - keyword: 搜索关键词；nil 时省略。
    ///   - sort: 发送 sort_by 与 sort_direction；nil 时使用服务端默认顺序。
    /// - Returns: SynologyPage<Genre>，将 data.total 和 data.genres 映射为 total/items。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func list(
        limit: Int = 1000, offset: Int = 0,
        libraryScope: SynologyLibraryScope = .shared, includeFields: String? = nil,
        filter: String? = nil, keyword: String? = nil,
        sort: SynologySortDescriptor? = nil
    ) async throws -> SynologyPage<Genre> {
        let result: GenreListResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.GENRE, method: "list", version: 3, httpMethod: .post
            ) {
                ("library", libraryScope.rawValue)
                ("limit", limit)
                ("offset", offset)
                ("additional", includeFields)
                ("filter", filter)
                ("keyword", keyword)
                if let sort {
                    ("sort_by", sort.field)
                    ("sort_direction", sort.direction.rawValue)
                }
            }
        )
        return SynologyPage(total: result.total, items: result.genres)
    }
}
