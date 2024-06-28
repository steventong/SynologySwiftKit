//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    /**
     构建音乐播放地址
     m4a: /webapi/AudioStation/stream.cgi/0.m4a?api=SYNO.AudioStation.Stream&version=2&method=stream&id=music_593
     */
    public func songStreamUrl(id: String, fileExtension: String? = nil, quality: SongStreamQuality) throws -> URL {
        if fileExtension == "m4a" {
            return try buildStreamURL(id: id, path: "\(id).m4a", method: "stream")
        }

        let songFileName = "/\(id).\(quality.format)"
        let method = quality == .ORIGINAL ? "stream" : "transcode"

        return try buildStreamURL(id: id, path: "\(id).m4a", method: "stream", format: quality.format, bitrate: quality.bitrate)
    }

    /**
     构造音乐播放地址
     */
    public func songStreamUrl(song: Song, quality: SongStreamQuality) throws -> URL {
        // todo
        return URL(string: "")!
    }
}

extension AudioStationApi {
    /**
     构建播放地址
     */
    private func buildStreamURL(id: String, path: String, method: String,
                                format: String? = nil,
                                bitrate: Int? = nil) throws -> URL {
        // build parameters
        var parameters: [String: Any] = ["id": id, "position": 0]

        if let format = format {
            parameters["format"] = format
        }

        if let bitrate = bitrate {
            parameters["bitrate"] = bitrate
        }

        // build api model
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, path: path, method: method, version: 2, parameters: parameters)
        // assemble stream url
        return try api.assembleRequestUrl()
    }

    private func isStreamAudio(song: Song, z: Bool) -> Bool {
        let filePath = song.path.lowercased()
        let bitrate = song.audio?.bitrate ?? 0
        let frequency = song.audio?.frequency ?? 0

        if filePath.hasSuffix(".aac") || filePath.hasSuffix(".m4a") || filePath.hasSuffix(".m4b") {
            return !isBitrateALAC(bitrate: bitrate)
        }

        if frequency > 48000 {
            return false
        }

        if filePath.hasSuffix(".mp3") {
            return true
        }

        if !filePath.hasSuffix(".3gp") && !filePath.hasSuffix(".mp4") && !filePath.hasSuffix(".ts") {
            if filePath.hasSuffix(".flac") {
                return !z
            }
            if filePath.hasSuffix(".ogg") {
                return true
            }
            if !filePath.hasSuffix(".mkv") && filePath.hasSuffix(".wav") {
                return true
            }
        }

        return false
    }

    private func isBitrateALAC(bitrate: Int) -> Bool {
        return bitrate > 320000
    }
}
