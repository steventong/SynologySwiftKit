//
//  ComposerApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class ComposerApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     composer list
     */
    public func list(limit: Int = 1000, offset: Int = 0, library: String = "shared", additional: String? = nil, filter: String? = nil, keyword: String? = nil, sort: (sort_by: String, sort_direction: String)? = nil) async throws -> (total: Int, data: [Composer]) {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.COMPOSER, method: "list", version: 2, httpMethod: .post) {
            ("library", library)
            ("limit", limit)
            ("offset", offset)
            ("additional", additional)
            ("filter", filter)
            ("keyword", keyword)
            if let sort {
                ("sort_by", sort.sort_by)
                ("sort_direction", sort.sort_direction)
            }
        }
        let result: ComposerListResult = try await apiClient.request(api)
        return (result.total, result.composers)
    }
}
