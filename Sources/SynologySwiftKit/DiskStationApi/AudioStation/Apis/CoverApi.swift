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
     获取歌曲封面 URL
     Get song cover URL
     */
    public func songCoverUrl(id: String, library: String = "all") throws -> URL {
        return try apiClient.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getsongcover", version: 1) {
            ("library", library)
            ("id", id)
        }
        )
    }

    /**
     获取专辑封面 URL
     Get album cover URL
     */
    public func albumCoverUrl(name: String, artistName: String, library: String = "all") throws -> URL {
        return try apiClient.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", library)
            ("album_name", name)
            ("album_artist_name", artistName)
        }
        )
    }

    /**
     获取艺术家封面 URL
     Get artist cover URL
     */
    public func artistCoverUrl(name: String, library: String = "all") throws -> URL {
        return try apiClient.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", library)
            ("artist_name", name)
        }
        )
    }

    /**
     获取作曲家封面 URL
     Get composer cover URL
     */
    public func composerCoverUrl(name: String, library: String = "all") throws -> URL {
        return try apiClient.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", library)
            ("composer_name", name)
        }
        )
    }
}
