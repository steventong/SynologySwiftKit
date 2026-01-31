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
    public func songCoverUrl(songId: String, library: String = "all") async throws -> URL {
        return try await apiClient.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getsongcover", version: 1) {
            ("library", library)
            ("id", songId)
        }
        )
    }

    /**
     获取专辑封面 URL
     Get album cover URL
     */
    public func albumCoverUrl(albumName: String, albumArtistName: String, library: String = "all") async throws -> URL {
        return try await apiClient.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", library)
            ("album_name", albumName)
            ("album_artist_name", albumArtistName)
        }
        )
    }

    /**
     获取艺术家封面 URL
     Get artist cover URL
     */
    public func artistCoverUrl(artistName: String, library: String = "all") async throws -> URL {
        return try await apiClient.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", library)
            ("artist_name", artistName)
        }
        )
    }

    /**
     获取作曲家封面 URL
     Get composer cover URL
     */
    public func composerCoverUrl(composerName: String, library: String = "all") async throws -> URL {
        return try await apiClient.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", library)
            ("composer_name", composerName)
        }
        )
    }
}
