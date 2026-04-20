//
//  ArtistApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class ArtistApi {
    private let apiClient: ApiClientProviding

    init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     query artist list
     */
    public func list(
        limit: Int = 1000, offset: Int = 0,
        libraryScope: SynologyLibraryScope = .shared, includeFields: String? = nil,
        filter: String? = nil, keyword: String? = nil,
        sort: SynologySortDescriptor? = nil
    ) async throws -> SynologyPage<Artist> {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.ARTIST, method: "list", version: 4, httpMethod: .post) {
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
        let result: ArtistListResult = try await apiClient.request(api)
        return SynologyPage(total: result.total, items: result.artists)
    }
}
