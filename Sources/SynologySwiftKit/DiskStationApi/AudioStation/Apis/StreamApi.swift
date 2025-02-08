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
     <p>DS audio 支持以下格式（其余格式无法播放）：AAC、AIF、AIFF、M4A、M4B、MP3、WAV、APE、FLAC、Ogg Vorbis、WMA、WMA VBR、WMA PRO。</p>
     <p>DS audio 支持以下格式（其余格式无法播放）：AAC、AIF、AIFF、M4A、M4B、MP3、WAV、APE、FLAC、Ogg Vorbis、WMA、WMA VBR、WMA PRO。</p>

     https://kb.synology.cn/zh-cn/DSM/tutorial/prevent_DS_audio_from_automatically_converting_audio_files

     请检查您的设备是否支持您的音频格式。
     iOS设备：iAAC，AIFF，APE，Apple Lossless（ALAC），M4A，M4B，MP3，WAV
     Android设备：AAC，FLAC，非alac M4A，M4B，MP3，WAV，Ogg Vorbis
     Synology NAS：AAC，AIF，AIFF，APE，Apple Lossless（ALAC），FLAC，M4A，M4B，MP3，WAV，Ogg Vorbis，WMA，WMA PRO，WMA VBR，DSD
     在DS audio >设置>转换中配置以下设置。
     转换：将转换格式设置为WAV，以确保高质量播放音乐。
     始终转换：在此不选择列出的任何格式，以避免在所有情况下进行转换。
     */
    public func songStreamUrl(id: String, path: String, bitrate: Int, frequency: Int,
                              quality: SongStreamQuality, customUrlRules: [String: String]? = nil) throws -> URL {
        // 基础参数
        let fileExtension = getExtFromFilePath(filePath: path)
        let idEncoded = UrlUtils.urlEncode(id)
        let pathEncoded = UrlUtils.urlEncode(path)

        // 根据云端配置规则
        // 配置地址：https://dsmusicapi.itwl.me/synology/audio-station/stream-rules
        // 自定义规则优先执行
        let dimensions: [String: Any] = ["id": id,
                                         "path": path,
                                         "bitrate": bitrate,
                                         "frequency": frequency,
                                         "quality": quality]
        // 匹配
        for (predicateStr, resultTemplate) in customUrlRules ?? [:] {
            let predicate = NSPredicate(format: predicateStr)
            if predicate.evaluate(with: dimensions) {
                // 动态替换变量
                var result = resultTemplate
                result = result.replacingOccurrences(of: "%ID%", with: id)
                result = result.replacingOccurrences(of: "%ID_ENCODED%", with: idEncoded)
                result = result.replacingOccurrences(of: "%PATH%", with: path)
                result = result.replacingOccurrences(of: "%PATH_ENCODED%", with: pathEncoded)
                result = result.replacingOccurrences(of: "%BITRATE%", with: "\(bitrate)")
                result = result.replacingOccurrences(of: "%FREQUENCY%", with: "\(frequency)")
                result = result.replacingOccurrences(of: "%QUALITY%", with: "\(quality)")
                // 固定参数
                if let host = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName) {
                    result = result.replacingOccurrences(of: "%HOST%", with: host)
                }
                if let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) {
                    result = result.replacingOccurrences(of: "%SID%", with: sid)
                }

                if let url = URL(string: result) {
                    return url
                }
            }
        }

        // build parameters
        var parameters: [String: Any] = ["id": UrlUtils.urlEncode(id)]

        // 构建播放地址 getPlayUrl
        // 当前的音频是否需要转码
        let isNeedToTransCode = isNeedToTransCode(id: id, path: path, bitrate: bitrate, frequency: frequency)
        // 用户选择原始音质（串流），且支持串流播放
        if quality == .ORIGINAL && !isNeedToTransCode {
            parameters["format"] = fileExtension

            let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, path: "/0.\(fileExtension)", method: "stream", version: 1, parameters: parameters)
            return try api.assembleRequestUrl()
        } else {
            parameters["format"] = "mp3"
            parameters["bitrate"] = getTransCodeBitrate(quality: quality)
           
            let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, path: "/0.mp3", method: "transcode", version: 1, parameters: parameters)
            return try api.assembleRequestUrl()
        }
    }
}

extension AudioStationApi {
    /**
     是否进行转码播放
     */
    private func isNeedToTransCode(id: String, path: String, bitrate: Int, frequency: Int) -> Bool {
        // 整轨音频文件不支持stream，强制转码
        if id.hasPrefix("music_v") || id.hasPrefix("music_p_v") {
            Logger.info("整轨音频文件不支持stream，强制转码, id: \(id)")
            return true
        }

        // 看看是串流（stream）还是转码（transcode）
        let isSupportStreamPlaying = isSupportStreamPlaying(path: path, bitrate: bitrate, frequency: frequency)
        return !isSupportStreamPlaying
    }

    /**

     */
    private func getTransCodeBitrate(quality: SongStreamQuality) -> Int {
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
        // 基本的机器都支持转码?
        // TODO: 应该从nas的接口获取 transcode_capability
        true
    }

    /**
     是否支持直接传音频流？支持的就不需要转码
     */
    private func isSupportStreamPlaying(path: String, bitrate: Int, frequency: Int) -> Bool {
        if frequency > 48000 {
            Logger.info("采样率大于48k，使用转码，path: \(path), frequency: \(frequency)")
            return false
        }

        let name = path.lowercased()

        if name.hasSuffix(".mp3") {
            return true
        }

        if name.hasSuffix(".3gp") || name.hasSuffix(".mp4") {
            Logger.info("特定格式，使用转码，path: \(path), .3gp/.mp4")
            return false
        }

        if name.hasSuffix(".m4a") && bitrate > 320000 {
            Logger.info("特定格式，比特率大于320k，使用转码，path: \(path), .m4a，bitrate: \(bitrate)")
            return false
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

        Logger.info("没有匹配到各种条件，默认使用转码")
        return false
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
