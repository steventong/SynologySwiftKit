//
//  StreamModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2025/2/8.
//

import Foundation

/// 音频播放方式。
public enum SongPlaybackMethod: String, Sendable {
    /// 直接流（原始音频流，不转码）
    case stream

    /// 转码流（服务器转码为兼容格式后流传输）
    case transcode
}

/// Audio Station 支持的转码输出格式。
public enum SongTranscodeFormat: String, CaseIterable, Sendable {
    case mp3
    case wav
}

/// 播放方案的决策原因，便于调用方记录日志和诊断。
public enum SongPlaybackDecisionReason: String, Sendable {
    case originalRequested
    case sourceWithinTargetBitrate
    case bitrateReduction
    case incompatibleSource
    case virtualTrack
    case transcodingUnavailable
}

/// 在构造播放 URL 之前确定的完整播放方案。
public struct SongPlaybackPlan: Sendable, Equatable {
    public let method: SongPlaybackMethod
    public let outputFormat: String
    public let bitrate: Int?
    public let reason: SongPlaybackDecisionReason

    public var fileExtension: String {
        ".\(outputFormat)"
    }

    public var cacheIdentity: String {
        [
            method.rawValue,
            outputFormat,
            bitrate.map(String.init) ?? "original",
        ].joined(separator: "-")
    }
}

/// 已完成决策并构造好 URL 的播放资源。
public struct SongPlaybackResource: Sendable {
    public let url: URL
    public let plan: SongPlaybackPlan
}

/// 无法为歌曲生成可播放资源时返回的错误。
public enum SongPlaybackError: LocalizedError {
    case missingFileExtension
    case unsupportedSourceFormat(String)

    public var errorDescription: String? {
        switch self {
        case .missingFileExtension:
            return "The song does not have a usable file extension."
        case let .unsupportedSourceFormat(format):
            return "The source format \(format) cannot be streamed and the server cannot transcode it."
        }
    }
}
