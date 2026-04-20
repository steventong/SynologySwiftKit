//
//  GenreApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class GenreApi {
    private let apiClient: ApiClientProviding

    init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     genre list
     */
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
