//
//  AlbumApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class AlbumApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /**
     album list
     */
    public func list(limit: Int = 1000, offset: Int = 0,
                     libraryScope: SynologyLibraryScope = .shared, includeFields: String? = nil,
                     filter: String? = nil, keyword: String? = nil,
                     sort: SynologySortDescriptor? = nil) async throws -> SynologyPage<Album> {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.ALBUM, method: "list", version: 3, httpMethod: .post) {
            ("limit", limit)
            ("offset", offset)
            ("library", libraryScope.rawValue)
            ("additional", includeFields)
            ("filter", filter)
            ("keyword", keyword)
            if let sort {
                ("sort_by", sort.field)
                ("sort_direction", sort.direction.rawValue)
            }
        }
        let result: AlbumListResult = try await apiClient.request(api)
        return SynologyPage(total: result.total, items: result.albums)
    }
}
