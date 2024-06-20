//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

extension AudioStationApi {
    public func folderList(id: String?) async throws -> (total: Int, data: [Folder]) {
        let api = try await SynoDiskStationApi(api: .SYNO_AUDIO_STATION_FOLDER, method: "list", version: 1, parameters: [
            "version": 3,
            "id": id ?? "",
            "library": "all",
            "additional": "song_tag,song_audio,song_rating",
            "limit": 5000,
            "offset": 0,
        ])

        let result = try await api.requestForData(resultType: FolderListResult.self)
        return (result.folder_total, result.items)
    }
}
