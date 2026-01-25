//
//  SearchApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class SearchApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     Search List
     */
    public func list(
        keyword: String, limit: Int = 1000, offset: Int = 0,
        additional: String? = nil,
        sort: (sort_by: String, sort_direction: String)? = nil
    ) async throws -> SearchResult {
        let result: SearchResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SEARCH, method: "list", version: 1, httpMethod: .post
            ) {
                ("keyword", keyword)
                ("limit", limit)
                ("offset", offset)
                ("additional", additional)
                if let sort {
                    ("sort_by", sort.sort_by)
                    ("sort_direction", sort.sort_direction)
                }
            }
        )
        return result
    }
}
