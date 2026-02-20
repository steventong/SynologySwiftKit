//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    /**
     genre list

     https://n:5001/webapi/AudioStation/genre.cgi

     limit: 1000
     method: list
     library: shared
     api: SYNO.AudioStation.Genre
     additional: avg_rating
     version: 3
     sort_by: name
     sort_direction: ASC

     */
    public func genreList(limit: Int = 1000, offset: Int = 0,
                          library: String = "shared", additional: String? = nil,
                          filter: String? = nil, keyword: String? = nil,
                          sort: (sort_by: String, sort_direction: String)? = nil) async throws -> (total: Int, data: [Genre]) {
        var parameters: [String: Any] = [
            "library": library,
            "limit": limit,
            "offset": offset,
        ]

        if let additional {
            parameters["additional"] = additional
        }

        if let filter {
            parameters["filter"] = filter
        }

        if let keyword {
            parameters["keyword"] = keyword
        }

        if let sort {
            parameters["sort_by"] = sort.sort_by
            parameters["sort_direction"] = sort.sort_direction
        }

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_GENRE, method: "list", version: 3, httpMethod: .post, parameters: parameters)

        let result = try await api.requestForData(resultType: GenreListResult.self)
        return (result.total, result.genres)
    }
}
