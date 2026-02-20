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

     https://:5001/webapi/AudioStation/artist.cgi

     offset: 1000
     limit: 1000
     sort_by: name
     sort_direction: ASC
     method: list
     library: shared
     api: SYNO.AudioStation.Artist
     additional: avg_rating
     version: 4
     Search in the Performance > Network track

     */
    public func artistList(limit: Int = 1000, offset: Int = 0,
                           library: String = "shared", additional: String? = nil,
                           filter: String? = nil, keyword: String? = nil,
                           sort: (sort_by: String, sort_direction: String)? = nil) async throws -> (total: Int, data: [Artist]) {
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

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_ARTIST, method: "list", version: 4, httpMethod: .post, parameters: parameters)

        let result = try await api.requestForData(resultType: ArtistListResult.self)
        return (result.total, result.artists)
    }
}
