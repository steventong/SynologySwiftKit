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

    /// 将播放器报告的通用媒体加载失败转换成 Audio Station 领域错误。
    ///
    /// 直流资源可能因源文件损坏或客户端解码能力不足而失败，Kit 无法在
    /// 缺少更多信息时归因给服务端。转码资源则由 Audio Station 负责生成
    /// 客户端声明可播放的格式，因此加载失败表示服务端返回了无效转码产物。
    public func playbackError(
        for failure: SongPlaybackFailure
    ) -> SongPlaybackError? {
        switch (method, failure) {
        case (.transcode, .failedToLoadMediaData):
            return .invalidTranscodedMedia
        case (.stream, .failedToLoadMediaData):
            return nil
        }
    }
}

/// 播放器反馈给 Kit 的平台无关失败类型。
public enum SongPlaybackFailure: Sendable, Equatable {
    case failedToLoadMediaData
}

/// 已完成决策并构造好 URL 的播放资源。
public struct SongPlaybackResource: Sendable {
    public let url: URL
    public let plan: SongPlaybackPlan
}

/// 无法为歌曲生成可播放资源时返回的错误。
public enum SongPlaybackError: LocalizedError, Sendable, Equatable {
    case missingFileExtension
    case unsupportedSourceFormat(String)
    case invalidTranscodedMedia

    public var errorDescription: String? {
        switch self {
        case .missingFileExtension:
            return "The song does not have a usable file extension."
        case let .unsupportedSourceFormat(format):
            return "The source format \(format) cannot be streamed and the server cannot transcode it."
        case .invalidTranscodedMedia:
            return "Audio Station returned invalid media data for the transcoded stream."
        }
    }
}
