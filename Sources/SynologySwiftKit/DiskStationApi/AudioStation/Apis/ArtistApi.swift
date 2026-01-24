//
//  ArtistApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    /**
     query artist list
     */
    public func artistList(
        limit: Int = 1000, offset: Int = 0,
        library: String = "shared", additional: String? = nil,
        filter: String? = nil, keyword: String? = nil,
        sort: (sort_by: String, sort_direction: String)? = nil
    ) async throws -> (total: Int, data: [Artist]) {
        var parameters: [String: Any] = [
            "library": library,
            "limit": limit,
            "offset": offset,
        ]
        if let additional { parameters["additional"] = additional }
        if let filter { parameters["filter"] = filter }
        if let keyword { parameters["keyword"] = keyword }
        if let sort {
            parameters["sort_by"] = sort.sort_by
            parameters["sort_direction"] = sort.sort_direction
        }

        let result: ArtistListResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.ARTIST, method: "list", version: 4, httpMethod: .post,
                parameters: parameters),
            resultType: ArtistListResult.self
        )
        return (result.total, result.artists)
    }
}
