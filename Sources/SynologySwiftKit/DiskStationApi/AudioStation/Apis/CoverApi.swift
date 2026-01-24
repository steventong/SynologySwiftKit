//
//  CoverApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    /**
     音乐封面
     */
    public func songCoverURL(songId: String) throws -> URL {
        try apiClient.buildUrl(
            ApiEndpoint(
                api: SynologyApi.AudioStation.cover, method: "getsongcover",
                parameters: [
                    "library": "all",
                    "id": songId,
                ])
        )
    }

    /**
     专辑封面
     */
    public func albumCoverURL(albumName: String, albumArtistName: String) throws -> URL {
        try apiClient.buildUrl(
            ApiEndpoint(
                api: SynologyApi.AudioStation.cover, method: "getcover", version: 3,
                parameters: [
                    "library": "all",
                    "album_name": albumName,
                    "album_artist_name": albumArtistName,
                ])
        )
    }

    /**
     艺术家封面
     */
    public func artistCoverURL(artistName: String) throws -> URL {
        try apiClient.buildUrl(
            ApiEndpoint(
                api: SynologyApi.AudioStation.cover, method: "getcover", version: 3,
                parameters: [
                    "library": "all",
                    "artist_name": artistName,
                ])
        )
    }

    /**
     作曲家封面
     */
    public func composerCoverURL(composerName: String) throws -> URL {
        try apiClient.buildUrl(
            ApiEndpoint(
                api: SynologyApi.AudioStation.cover, method: "getcover", version: 3,
                parameters: [
                    "version": 3,
                    "library": "all",
                    "composer_name": composerName,
                ])
        )
    }
}
