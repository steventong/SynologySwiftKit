//
//  AlbumApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    /**
     album list
     */
    public func albumList(
        limit: Int = 1000, offset: Int = 0,
        library: String = "shared", additional: String? = nil,
        filter: String? = nil, keyword: String? = nil,
        sort: (sort_by: String, sort_direction: String)? = nil
    ) async throws -> (total: Int, data: [Album]) {
        var parameters: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "library": library,
        ]
        if let additional { parameters["additional"] = additional }
        if let filter { parameters["filter"] = filter }
        if let keyword { parameters["keyword"] = keyword }
        if let sort {
            parameters["sort_by"] = sort.sort_by
            parameters["sort_direction"] = sort.sort_direction
        }

        let result: AlbumListResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: .SYNO_AUDIO_STATION_ALBUM, method: "list", version: 3, httpMethod: .post,
                parameters: parameters),
            resultType: AlbumListResult.self
        )
        return (result.total, result.albums)
    }
}
