//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    /**
     音乐封面
     /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getsongcover&version=1&library=all&id=music_6834&_sid=
     */
    public func songCoverURL(songId: String) throws -> URL {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_COVER, method: "getsongcover", parameters: [
            "library": "all",
            "id": songId,
        ])

        return try api.assembleRequestUrl()
    }

    /**
     专辑封面
     /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&album_name=%E4%B8%83%E9%87%8C%E9%A6%99&album_artist_name=
     */
    public func albumCoverURL(albumName: String, albumArtistName: String) throws -> URL {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_COVER, method: "getcover", version: 3, parameters: [
            "library": "all",
            "album_name": albumName,
            "album_artist_name": albumArtistName,
        ])

        return try api.assembleRequestUrl()
    }

    /**
     GET /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&artist_name=Backstreet%20Boys
     */
    public func artistCoverURL(artistName: String) throws -> URL {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_COVER, method: "getcover", version: 3, parameters: [
            "library": "all",
            "artist_name": artistName,
        ])

        return try api.assembleRequestUrl()
    }

    /**
      /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&composer_name=%E4%BA%94%E6%9C%88%E5%A4%A9
     */
    public func composerCoverURL(composerName: String) throws -> URL {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_COVER, method: "getcover", version: 3, parameters: [
            "version": 3,
            "library": "all",
            "composer_name": composerName,
        ])

        return try api.assembleRequestUrl()
    }
}
