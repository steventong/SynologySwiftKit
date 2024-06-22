//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    /**
     High: /webapi/AudioStation/stream.cgi/0.wav?api=SYNO.AudioStation.Stream&version=2&method=transcode&format=wav&id=
     M: /webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=transcode&format=mp3&id=
     L: /webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=transcode&format=mp3&id=

     Original: /webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=stream&id= ??
     Original: /webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=stream&id= ??   format=wav
     */
    public func songStreamUrl(id: String, position: Int = 0, quality: SongStreamQuality) throws -> URL {
        let songFileName = "/\(id).\(quality.format)"
        let method = quality == .ORIGINAL ? "stream" : "transcode"

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, path: songFileName, method: method, version: 2, parameters: [
            "id": id,
            "position": position,
            "format": quality.format,
            "bitrate": quality.bitrate ?? "",
        ])

        return try api.assembleRequestUrl()
    }
}
