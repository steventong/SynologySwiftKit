//
//  FolderApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class FolderApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    public func list(id: String?) async throws -> (total: Int, data: [Folder]) {
        let result: FolderListResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.FOLDER, method: "list") {
                ("version", 3)
                ("id", id ?? "")
                ("library", "all")
                ("additional", "song_tag,song_audio,song_rating")
                ("limit", 5000)
                ("offset", 0)
            }
        )
        return (result.folderTotal, result.items)
    }
}
