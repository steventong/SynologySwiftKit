//
//  ComposerApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - ComposerApi

/// 作曲家查询 API 客户端
/// Composer query API client
public final class ComposerApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// 查询作曲家列表
    /// Query composer list
    public func list(limit: Int = 1000, offset: Int = 0, libraryScope: SynologyLibraryScope = .shared, includeFields: String? = nil, filter: String? = nil, keyword: String? = nil, sort: SynologySortDescriptor? = nil) async throws -> SynologyPage<Composer> {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.COMPOSER, method: "list", version: 2, httpMethod: .post) {
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
        let result: ComposerListResult = try await apiClient.request(api)
        return SynologyPage(total: result.total, items: result.composers)
    }
}
