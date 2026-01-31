//
//  ArtistApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class ArtistApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     query artist list
     */
    public func list(
        limit: Int = 1000, offset: Int = 0,
        library: String = "shared", additional: String? = nil,
        filter: String? = nil, keyword: String? = nil,
        sort: (sort_by: String, sort_direction: String)? = nil
    ) async throws -> (total: Int, data: [Artist]) {
        let result: ArtistListResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.ARTIST, method: "list", version: 4, httpMethod: .post
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
        return (result.total, result.artists)
    }
}
