//
//  SearchApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class SearchApi {
    private let apiClient: ApiClientProviding

    init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     Search List
     */
    public func list(
        keyword: String, limit: Int = 1000, offset: Int = 0,
        includeFields: String? = nil,
        sort: SynologySortDescriptor? = nil
    ) async throws -> AudioStationSearchResults {
        let result: SearchResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SEARCH, method: "list", version: 1, httpMethod: .post
            ) {
                ("keyword", keyword)
                ("limit", limit)
                ("offset", offset)
                ("additional", includeFields)
                if let sort {
                    ("sort_by", sort.field)
                    ("sort_direction", sort.direction.rawValue)
                }
            }
        )
        return AudioStationSearchResults(
            albums: SynologyPage(total: result.albumTotal, items: result.albums),
            artists: SynologyPage(total: result.artistTotal, items: result.artists),
            songs: SynologyPage(total: result.songTotal, items: result.songs)
        )
    }
}
