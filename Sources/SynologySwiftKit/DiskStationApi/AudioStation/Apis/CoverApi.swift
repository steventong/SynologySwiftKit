//
//  CoverApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class CoverApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     获取封面
     Get cover image data
     */
    public func get(id: String) async throws -> Data {
        // cover.cgi
        // api=SYNO.AudioStation.Cover&method=getcover&version=3&library=shared&id=music_18521 // song id
        let result: Data = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3
            ) {
                ("library", "shared")
                ("id", id)
            },
            rawResponse: true
        )
        return result
    }

    /**
     通过 URL 获取封面（某些情况封面可能在不同路径）
     */
    public func getWithUrl(url: String) async throws -> Data {
        let result: Data = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.COVER, customPath: url, httpMethod: .get) {
                // No parameters needed usually for custom path direct access
            },
            rawResponse: true
        )
        return result
    }

    /**
     从文件夹路径获取封面
     */
    public func getFolderCover(path: String) async throws -> Data {
        // api=SYNO.AudioStation.Cover&output_default=true&method=getcover&version=3&library=shared&id=folder_path_music
        // section index... not implemented in swift version yet
        // Fallback to library=shared & id=folder_path (if server supports)

        // This logic seems incomplete in original file.
        // Assuming we just call standard cover API with folder id pattern if applicable
        // Or standard request.

        // Use folder variant
        let result: Data = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3
            ) {
                ("library", "shared")
                ("id", path)  // assuming path is passed as ID for folders in some contexts
            },
            rawResponse: true
        )
        return result
    }
}
