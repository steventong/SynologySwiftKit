//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    /**
     query artist list
     */
    public func artistList(limit: Int = 1000, offset: Int = 0,
                           library: String = "shared",
                           filter: String? = nil, keyword: String? = nil,
                           sort_by: String = "name", sort_direction: String = "ASC") async throws -> (total: Int, data: [Artist]) {
        var parameters: [String: Any] = [
            "library": library,
            "limit": limit,
            "offset": offset,
            "sort_by": sort_by,
            "sort_direction": sort_direction,
        ]

        if let filter {
            parameters["filter"] = filter
        }

        if let keyword {
            parameters["keyword"] = keyword
        }

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_ARTIST, method: "list", version: 4, parameters: parameters)

        let result = try await api.requestForData(resultType: ArtistListResult.self)
        return (result.total, result.artists)
    }
}
