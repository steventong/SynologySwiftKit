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
    public func songStreamUrl(id: String, path: String, bitrate: Int, frequency: Int, quality: SongStreamQuality) throws -> URL {
        // build parameters
        var parameters: [String: Any] = ["id": encodeIdForURL(id: id)]

        // 构建播放地址 getPlayUrl
        if isToTransCode(id: id, path: path, bitrate: bitrate, frequency: frequency) {
            if isSupportMP3() && isFormatMp3() {
                parameters["format"] = "mp3"
                parameters["bitrate"] = downloadBitrate(quality: quality)
                parameters["ext"] = ".mp3"
            } else if isSupportWAV() {
                parameters["format"] = "wav"
                parameters["ext"] = ".wav"
            }

            let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, path: path, method: "transcode", version: 1, parameters: parameters)
            return try api.assembleRequestUrl()
        } else {
            parameters["ext"] = getExtFromFilePath(filePath: path)

            let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, path: path, method: "stream", version: 1, parameters: parameters)
            return try api.assembleRequestUrl()
        }
    }
}

extension AudioStationApi {
    /**
     是否转码播放
     */
    private func isToTransCode(id: String, path: String, bitrate: Int, frequency: Int) -> Bool {
        let isStreamPlaying = isStreamAudio(path: path, bitrate: bitrate, frequency: frequency)

        // 基本的机器都支持转码
        if isSupportTranscoding() {
            if isStreamPlaying == true {
                return true
            }
        }

        if id.hasPrefix("music_v") || id.hasPrefix("music_p_v") {
            return true
        }

        return false
    }

    /**

     */
    private func downloadBitrate(quality: SongStreamQuality) -> Int {
        switch quality {
        case .ORIGINAL:
            return 128000
        case .HIGH:
            return 320000
        case .MEDIUM:
            return 192000
        case .LOW:
            return 128000
        }
    }

    /**
     是否支持转码播放
     */
    private func isSupportTranscoding() -> Bool {
        // 基本的机器都支持转码，应该从nas的接口获取 transcode_capability
        true
    }

    /**
     是否支持直接传音频流？
     */
    private func isStreamAudio(path: String, bitrate: Int, frequency: Int) -> Bool {
        if frequency > 48000 {
            return false
        }

        let name = path.lowercased()

        if name.hasSuffix(".mp3") {
            return true
        }

        if name.hasSuffix(".3gp") || name.hasSuffix(".mp4") {
            return false
        }

        if name.hasSuffix(".m4a") {
            return bitrate <= 320000
        }

        if name.hasSuffix(".m4b") {
            return true
        }

        if name.hasSuffix(".aac") {
            return true
        }

        if name.hasSuffix(".flac") {
            return true
        }
        if name.hasSuffix(".ogg") {
            return true
        }
        if name.hasSuffix(".mkv") {
            return false
        }
        if name.hasSuffix(".wav") {
            return true
        }

        return false
    }

    /**
     encodeIdForURL
     */
    private func encodeIdForURL(id: String) -> String {
        return id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
    }

    /**
     nas接口返回是否支持mp3转码
     */
    private func isSupportMP3() -> Bool {
        true
    }

    /**
     nas接口返回是否支持wav转码
     */
    private func isSupportWAV() -> Bool {
        true
    }

    /**
     if mp3 file
     */
    private func isFormatMp3() -> Bool {
        // 转码设置？
        return true
    }

    /** 获取文件的扩展名**/
    private func getExtFromFilePath(filePath: String) -> String {
        guard let pos = filePath.lastIndex(of: ".") else {
            return "."
        }
        let ext = filePath[filePath.index(after: pos)...]
        return "." + String(ext)
    }
}
