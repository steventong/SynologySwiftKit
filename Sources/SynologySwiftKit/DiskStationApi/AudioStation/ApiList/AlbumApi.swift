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

     api: SYNO.AudioStation.Album

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
    func albumList(limit: Int, sort: (sort_by: String, sort_direction: String)?) async throws -> (total: Int, data: [Album]) {
        var parameters: [String: Any] = [
            "limit": limit,
            "library": "shared",
            "additional": "avg_rating",
        ]

        if let sort {
            parameters["sort_by"] = sort.sort_by
            parameters["sort_direction"] = sort.sort_direction
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_ALBUM, method: "list", version: 3, parameters: parameters)

        do {
            let result = try await api.requestForData(resultType: AlbumListResult.self)
            return (result.total, result.albums)
        } catch {
            Logger.error("AudioStationApi.AlbumApi.albumList error: \(error)")
        }

        return (0, [])
    }
}
