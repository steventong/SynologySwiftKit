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
        let streamMethod = getAudioStreamForceMethod(id: id, path: path, bitrate: bitrate, frequency: frequency)
        if streamMethod == .STREAM {
            // must use stream
            return try buildStreamUrl(fileExtension: fileExtension, parameters: &parameters)
        } else if streamMethod == .TRANSCODE {
            // must by transcode
            return try buildTranscodeUrl(fileExtension: fileExtension, quality: quality, parameters: &parameters)
        } else if quality == .ORIGINAL {
            // user choose use original (stream)
            return try buildStreamUrl(fileExtension: fileExtension, parameters: &parameters)
        } else {
            // user choose transcode
            return try buildTranscodeUrl(fileExtension: fileExtension, quality: quality, parameters: &parameters)
        }
    }
}

extension AudioStationApi {
    /**
      播放模式

      AVPlayer（iOS 原生播放器）支持播放的音视频格式主要取决于 iOS 系统的解码能力 和 AVFoundation 框架的支持。以下是官方支持的格式：
      音频格式（Audio Formats）

     AVPlayer 支持的主要音频格式包括：
         •    AAC（Advanced Audio Codec）：.m4a、.mp3、.mp4
         •    MP3：.mp3
         •    Apple Lossless (ALAC)：.m4a
         •    FLAC（iOS 11+）：.flac
         •    AIFF（Audio Interchange File Format）：.aiff、.aif
         •    WAV：.wav

     不支持（需要转码）： APE、WMA、OGG 等。
      */
    private func getAudioStreamForceMethod(id: String, path: String, bitrate: Int, frequency: Int) -> StreamMethodEnum? {
        // 整轨音频文件不支持stream，强制转码
        if id.hasPrefix("music_v") || id.hasPrefix("music_p_v") {
            Logger.info("整轨音频文件不支持stream，强制转码, id: \(id)")
            return .TRANSCODE
        }

        // 根据文件类型来判断
//        if frequency > 48000 {
//            Logger.info("采样率大于48k，使用转码，path: \(path), frequency: \(frequency)")
//            return .TRANSCODE
//        }

        let _path = path.lowercased()

//        if _path.hasSuffix(".mp3") {
//            return .TRANSCODE
//        }

//        if _path.hasSuffix(".3gp") || _path.hasSuffix(".mp4") {
//            Logger.info("特定格式，使用转码，path: \(path), .3gp/.mp4")
//            return .STREAM
//        }
//
//        if _path.hasSuffix(".m4a") && bitrate > 320000 {
//            Logger.info("特定格式，比特率大于320k，使用转码，path: \(path), .m4a，bitrate: \(bitrate)")
//            return false
//        }

        if _path.hasSuffix(".m4a") {
            Logger.info("特定格式：.m4a，使用串流，path: \(path)")
            return .STREAM
        }

        if _path.hasSuffix(".dsf") || _path.hasSuffix(".dff") {
            Logger.info("特定格式：.dsf/.dff，使用转码，path: \(path)")
            return .TRANSCODE
        }
//
//        if _path.hasSuffix(".m4b") {
//            return true
//        }
//
        if _path.hasSuffix(".aac") {
            return .TRANSCODE
        }
//
//        if _path.hasSuffix(".flac") {
//            return true
//        }
//
//        if _path.hasSuffix(".ogg") {
//            return true
//        }
//
//        if _path.hasSuffix(".mkv") {
//            return false
//        }
//
//        if _path.hasSuffix(".wav") {
//            return true
//        }
//
//        Logger.info("没有匹配到各种条件，默认使用转码")
//        return false
        return nil
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

    /**
     buildStreamUrl
     */
    private func buildStreamUrl(fileExtension: String, parameters: inout [String: Any]) throws -> URL {
        parameters["format"] = fileExtension

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, path: "/0\(fileExtension)", method: "stream", version: 1, parameters: parameters)
        return try api.assembleRequestUrl()
    }

    /**
     buildTranscodeUrl
     */
    private func buildTranscodeUrl(fileExtension: String, quality: SongStreamQuality, parameters: inout [String: Any]) throws -> URL {
        parameters["format"] = "mp3"
        parameters["bitrate"] = getTransCodeBitrate(quality: quality)

        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, path: "/0.mp3", method: "transcode", version: 1, parameters: parameters)
        return try api.assembleRequestUrl()
    }
}
