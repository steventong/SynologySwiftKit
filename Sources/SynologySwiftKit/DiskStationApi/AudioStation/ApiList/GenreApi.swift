//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func genreList() async throws -> (total: Int, data: [Genre]) {
        let api = try SynoDiskStationApi(api: .SYNO_AUDIO_STATION_GENRE, method: "list", version: 1, parameters: [
            "library": "all",
            "limit": 5000,
            "offset": 0,
            "sort_direction": "asc",
        ])

        let result = try await api.requestForData(resultType: GenreListResult.self)
        return (result.total, result.genres)
    }
}
