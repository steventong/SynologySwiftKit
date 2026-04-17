//
//  StreamApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation
import OSLog

public final class StreamApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     build song stream url
     */
    public func getStreamUrl(id: String, path: String, bitrate: Int, frequency: Int, fileExtension: String = ".mp3", quality: SongStreamQuality) async throws -> URL {
        // 如果是整轨的，直接返回mp3播放地址
        if id.hasPrefix("music_v") || id.hasPrefix("music_p_v") {
            Logger.info("整轨音频文件不支持stream，使用转码URL，id: \(id)")
            let api = ApiEndpoint(api: SynologyApi.AudioStation.STREAM, method: "transcode", version: 2, pathSuffix: "/0.mp3", sidOnQuery: true) {
                ("format", "mp3")
                ("id", id)
            }
            return try await apiClient.buildUrl(api)
        }

        // build parameters
        var parameters: ApiParameters = ["id": .string(UrlUtils.urlEncode(id))]

        // 构建播放地址 getPlayUrl
        // 当前的音频是否需要转码
        let streamMethod = getAudioStreamForceMethod(
            id: id, path: path, bitrate: bitrate, frequency: frequency)

        if streamMethod == .STREAM {
            // must use stream
            return try await buildStreamUrl(fileExtension: fileExtension, parameters: &parameters)
        } else if streamMethod == .TRANSCODE {
            // must by transcode
            return try await buildTranscodeUrl(fileExtension: fileExtension, quality: quality, parameters: &parameters)
        } else if quality == .ORIGINAL {
            // user choose use original (stream)
            return try await buildStreamUrl(fileExtension: fileExtension, parameters: &parameters)
        } else {
            // user choose transcode
            return try await buildTranscodeUrl(fileExtension: fileExtension, quality: quality, parameters: &parameters)
        }
    }

    // MARK: - Private Helpers

    private enum StreamMethodEnum {
        case STREAM
        case TRANSCODE
    }

    private func getAudioStreamForceMethod(id: String, path: String, bitrate: Int, frequency: Int) -> StreamMethodEnum? {
        // 整轨音频文件不支持stream，强制转码
        if id.hasPrefix("music_v") || id.hasPrefix("music_p_v") {
            Logger.info("整轨音频文件不支持stream，强制转码, id: \(id)")
            return .TRANSCODE
        }

        let _path = path.lowercased()

        if _path.hasSuffix(".m4a") {
            Logger.info("特定格式：.m4a，使用串流，path: \(path)")
            return .STREAM
        }

        if _path.hasSuffix(".dsf") || _path.hasSuffix(".dff") {
            Logger.info("特定格式：.dsf/.dff，使用转码，path: \(path)")
            return .TRANSCODE
        }

        if _path.hasSuffix(".ogg") {
            Logger.info("特定格式：.ogg，使用转码，path: \(path)")
            return .TRANSCODE
        }

        if _path.hasSuffix(".mkv") {
            Logger.info("特定格式：.mkv，使用转码，path: \(path)")
            return .TRANSCODE
        }

        return nil
    }

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

    private func buildStreamUrl(fileExtension: String, parameters: inout ApiParameters) async throws -> URL {
        parameters["format"] = .string(fileExtension)

        let api = ApiEndpoint(api: SynologyApi.AudioStation.STREAM, method: "stream", pathSuffix: "/0\(fileExtension)", sidOnQuery: true) {
            let pairs: [ApiParametersBuilder.Parameter] = parameters.map { key, value in
                (key, value as ApiParameterValueConvertible)
            }
            for pair in pairs {
                pair
            }
        }
        return try await apiClient.buildUrl(api)
    }

    private func buildTranscodeUrl(fileExtension: String, quality: SongStreamQuality, parameters: inout ApiParameters) async throws -> URL {
        parameters["format"] = .string("mp3")
        parameters["bitrate"] = .int(getTransCodeBitrate(quality: quality))

        let api = ApiEndpoint(api: SynologyApi.AudioStation.STREAM, method: "transcode", pathSuffix: "/0.mp3", sidOnQuery: true) {
            let pairs: [ApiParametersBuilder.Parameter] = parameters.map { key, value in
                (key, value as ApiParameterValueConvertible)
            }
            for pair in pairs {
                pair
            }
        }
        return try await apiClient.buildUrl(api)
    }
}
