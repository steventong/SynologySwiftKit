//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    /**
     album list

     https://:5001/webapi/AudioStation/album.cgi

     limit: 1000
     method: list
     library: shared
     api: SYNO.AudioStation.Album
     additional: avg_rating
     version: 3
     sort_by: name
     sort_direction: ASC

     {
         "data": {
             "albums": [
                 {
                     "additional": {
                         "avg_rating": {
                             "rating": 0
                         }
                     },
                     "album_artist": "张学友",
                     "artist": "",
                     "display_artist": "张学友",
                     "name": "等你等到我心痛",
                     "year": 1993
                 }
             ],
             "offset": 0,
             "total": 1574
         },
         "success": true
     }

     */
    public func albumList(limit: Int = 1000, offset: Int = 0,
                          library: String = "shared",
                          filter: String? = nil, keyword: String? = nil,
                          sort: (sort_by: String, sort_direction: String)? = nil) async throws -> (total: Int, data: [Album]) {
        var parameters: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "library": library,
        ]

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

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_ALBUM, method: "list", version: 3, parameters: parameters)

        let result = try await api.requestForData(resultType: AlbumListResult.self)
        return (result.total, result.albums)
    }
}
