//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func artistList() async throws -> (total: Int, data: [Artist]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_ARTIST, method: "list", version: 1, parameters: [
            "library": "all",
            "limit": 5000,
            "offset": 0,
            "sort_by": "name",
            "sort_direction": "asc",
        ])

        do {
            let result = try await api.requestForData(resultType: ArtistListResult.self)
            return (result.total, result.artists)
        } catch {
            Logger.error("AudioStationApi.ArtistApi.artistList error: \(error)")
        }

        return (0, [])
    }
}
