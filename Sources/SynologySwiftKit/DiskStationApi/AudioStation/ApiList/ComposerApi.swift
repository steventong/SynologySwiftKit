//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func composerList() async throws -> (total: Int, data: [Composer]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_COMPOSER, method: "list", version: 1, parameters: [
            "library": "all",
            "limit": 5000,
            "offset": 0,
            "sort_direction": "asc",
        ])

        do {
            let result = try await api.requestForData(resultType: ComposerListResult.self)
            return (result.total, result.composers)
        } catch {
            Logger.error("AudioStationApi.ComposerApi.composerList error: \(error)")
        }

        return (0, [])
    }
}