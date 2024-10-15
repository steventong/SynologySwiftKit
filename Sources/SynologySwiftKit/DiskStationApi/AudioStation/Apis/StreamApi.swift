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
        let streamFormat = songStreamFormat(fileExtension: fileExtension ?? "", quality: quality)
        let streamMethod = songStreamMethod(fileExtension: fileExtension ?? "", quality: quality)
        let songFileName = "/\(id).\(streamFormat)"

        if streamMethod == "stream" {
            // 原始格式播放
            return try buildStreamURL(id: id, path: songFileName, method: streamMethod)
        } else {
            // 转码播放
            return try buildStreamURL(id: id, path: songFileName, method: streamMethod, format: streamFormat, bitrate: quality.bitrate)
        }
    }

    /**
     构造音乐播放地址
     */
    public func songStreamUrl(song: Song, quality: SongStreamQuality) throws -> URL {
        // todo
        return URL(string: "")!
    }

    /**
     文件扩展名
     */
    public func songStreamFormat(fileExtension: String, quality: SongStreamQuality) -> String {
        switch fileExtension.lowercased() {
        case "m4a":
            "m4a"
        case "ogg":
            "ogg"
        default:
            quality.format
        }
    }

    /**
     传输方式
     */
    public func songStreamMethod(fileExtension: String, quality: SongStreamQuality) -> String {
        switch fileExtension.lowercased() {
        case "m4a":
            "stream"
        case "ogg":
            "stream"
        default:
            quality == .ORIGINAL ? "stream" : "transcode"
        }
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
