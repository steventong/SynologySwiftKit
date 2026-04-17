//
//  GenreApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class GenreApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     genre list
     */
    public func list(
        limit: Int = 1000, offset: Int = 0,
        library: String = "shared", additional: String? = nil,
        filter: String? = nil, keyword: String? = nil,
        sort: (sort_by: String, sort_direction: String)? = nil
    ) async throws -> (total: Int, data: [Genre]) {
        let result: GenreListResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.GENRE, method: "list", version: 3, httpMethod: .post
            ) {
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
        )
        return (result.total, result.genres)
    }
}
