//
//  CoverApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public final class CoverApi {
    private let urlBuilder: ApiURLBuilding

    init(urlBuilder: ApiURLBuilding) {
        self.urlBuilder = urlBuilder
    }

    /**
     获取歌曲封面 URL
     Get song cover URL
     */
    public func songCoverURL(songID: String, libraryScope: SynologyLibraryScope = .all) async throws -> URL {
        return try await urlBuilder.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getsongcover", version: 1) {
            ("library", libraryScope.rawValue)
            ("id", songID)
        }
        )
    }

    /**
     获取专辑封面 URL
     Get album cover URL
     */
    public func albumCoverURL(albumName: String, albumArtistName: String, libraryScope: SynologyLibraryScope = .all) async throws -> URL {
        return try await urlBuilder.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", libraryScope.rawValue)
            ("album_name", albumName)
            ("album_artist_name", albumArtistName)
        }
        )
    }

    /**
     获取艺术家封面 URL
     Get artist cover URL
     */
    public func artistCoverURL(artistName: String, libraryScope: SynologyLibraryScope = .all) async throws -> URL {
        return try await urlBuilder.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", libraryScope.rawValue)
            ("artist_name", artistName)
        }
        )
    }

    /**
     获取作曲家封面 URL
     Get composer cover URL
     */
    public func composerCoverURL(composerName: String, libraryScope: SynologyLibraryScope = .all) async throws -> URL {
        return try await urlBuilder.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", libraryScope.rawValue)
            ("composer_name", composerName)
        }
        )
    }
}
