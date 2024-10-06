//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    /**
     composer list

     https://:5001/webapi/AudioStation/composer.cgi

     limit: 1000
     method: list
     library: shared
     api: SYNO.AudioStation.Composer
     additional: avg_rating
     version: 2
     sort_by: name
     sort_direction: ASC
     */
    public func composerList(limit: Int = 1000, offset: Int = 0,
                             library: String = "shared", additional: String? = nil,
                             filter: String? = nil, keyword: String? = nil,
                             sort: (sort_by: String, sort_direction: String)? = nil) async throws -> (total: Int, data: [Composer]) {
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

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_COMPOSER, method: "list", version: 2, httpMethod: .post, parameters: parameters)

        let result = try await api.requestForData(resultType: ComposerListResult.self)
        return (result.total, result.composers)
    }
}
