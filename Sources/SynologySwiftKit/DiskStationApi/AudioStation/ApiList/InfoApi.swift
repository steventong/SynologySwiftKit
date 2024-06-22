//
//  File.swift
//
//
//  Created by Steven on 2024/6/22.
//

import Foundation

extension AudioStationApi {
    public func info_getinfo(id: String?) async throws -> AudioStationInfo {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_INFO, method: "getinfo", version: 4)

        return try await api.requestForData(resultType: AudioStationInfo.self)
    }
}
