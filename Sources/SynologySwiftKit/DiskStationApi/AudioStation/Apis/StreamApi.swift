//
//  StreamApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation
import OSLog

public final class StreamApi {
    private let urlBuilder: ApiURLBuilding
    private let transcodeCapabilityProvider: AudioTranscodeCapabilityProviding

    init(
        urlBuilder: ApiURLBuilding,
        transcodeCapabilityProvider: AudioTranscodeCapabilityProviding
    ) {
        self.urlBuilder = urlBuilder
        self.transcodeCapabilityProvider = transcodeCapabilityProvider
    }

    /// 构造播放资源。URL、最终格式和缓存身份均来自同一播放方案。
    public func playbackResource(
        for source: SongPlaybackSource,
        quality: SongStreamQuality,
        preferredTranscodeFormat: SongTranscodeFormat = .mp3
    ) async throws -> SongPlaybackResource {
        let supportedFormats = try await transcodeCapabilityProvider.supportedTranscodeFormats()
        let plan = try playbackPlan(
            for: source,
            quality: quality,
            preferredTranscodeFormat: preferredTranscodeFormat,
            supportedTranscodeFormats: supportedFormats
        )
        let url = try await buildPlaybackURL(for: source, plan: plan)
        return SongPlaybackResource(url: url, plan: plan)
    }

    /// 兼容只需要 URL 的调用方。
    public func playbackURL(
        for source: SongPlaybackSource,
        quality: SongStreamQuality,
        preferredTranscodeFormat: SongTranscodeFormat = .mp3
    ) async throws -> URL {
        try await playbackResource(
            for: source,
            quality: quality,
            preferredTranscodeFormat: preferredTranscodeFormat
        ).url
    }

    /// 按官方客户端的顺序决定直流或转码：
    /// 1. 先判断整轨和客户端格式兼容性。
    /// 2. 可直放时仅在源码率高于目标码率时压缩。
    /// 3. 需要转码时根据 NAS 能力选择实际输出格式。
    func playbackPlan(
        for source: SongPlaybackSource,
        quality: SongStreamQuality,
        preferredTranscodeFormat: SongTranscodeFormat,
        supportedTranscodeFormats: Set<SongTranscodeFormat>
    ) throws -> SongPlaybackPlan {
        let sourceFormat = try normalizedSourceFormat(source.fileExtension)
        let isVirtualTrack = source.id.hasPrefix("music_v")
            || source.id.hasPrefix("music_p_v")
        let isDirectPlayable = Self.directPlayFormats.contains(sourceFormat)

        if isVirtualTrack {
            return try transcodePlan(
                sourceFormat: sourceFormat,
                quality: quality,
                preferredFormat: preferredTranscodeFormat,
                supportedFormats: supportedTranscodeFormats,
                reason: .virtualTrack
            )
        }

        if !isDirectPlayable {
            return try transcodePlan(
                sourceFormat: sourceFormat,
                quality: quality,
                preferredFormat: preferredTranscodeFormat,
                supportedFormats: supportedTranscodeFormats,
                reason: .incompatibleSource
            )
        }

        guard let targetBitrate = quality.bitrate else {
            return streamPlan(sourceFormat: sourceFormat, reason: .originalRequested)
        }

        guard source.bitrate > targetBitrate else {
            return streamPlan(sourceFormat: sourceFormat, reason: .sourceWithinTargetBitrate)
        }

        // WAV 不能降低传输码率；NAS 没有 MP3 转码能力时继续使用兼容的原始流。
        guard supportedTranscodeFormats.contains(.mp3),
              preferredTranscodeFormat == .mp3 else {
            return streamPlan(sourceFormat: sourceFormat, reason: .transcodingUnavailable)
        }

        return SongPlaybackPlan(
            method: .transcode,
            outputFormat: SongTranscodeFormat.mp3.rawValue,
            bitrate: targetBitrate,
            reason: .bitrateReduction
        )
    }
}

private extension StreamApi {
    /// Apple 平台由 AVFoundation 直接解码的音频容器。
    static let directPlayFormats: Set<String> = [
        "aac",
        "aif",
        "aiff",
        "caf",
        "flac",
        "m4a",
        "m4b",
        "mp3",
        "wav",
    ]

    func normalizedSourceFormat(_ fileExtension: String) throws -> String {
        let format = fileExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        guard !format.isEmpty else {
            throw SongPlaybackError.missingFileExtension
        }
        return format
    }

    func streamPlan(
        sourceFormat: String,
        reason: SongPlaybackDecisionReason
    ) -> SongPlaybackPlan {
        SongPlaybackPlan(
            method: .stream,
            outputFormat: sourceFormat,
            bitrate: nil,
            reason: reason
        )
    }

    func transcodePlan(
        sourceFormat: String,
        quality: SongStreamQuality,
        preferredFormat: SongTranscodeFormat,
        supportedFormats: Set<SongTranscodeFormat>,
        reason: SongPlaybackDecisionReason
    ) throws -> SongPlaybackPlan {
        let outputFormat: SongTranscodeFormat?
        if supportedFormats.contains(preferredFormat) {
            outputFormat = preferredFormat
        } else if supportedFormats.contains(.mp3) {
            outputFormat = .mp3
        } else if supportedFormats.contains(.wav) {
            outputFormat = .wav
        } else {
            outputFormat = nil
        }

        guard let outputFormat else {
            throw SongPlaybackError.unsupportedSourceFormat(sourceFormat)
        }

        let bitrate: Int?
        switch outputFormat {
        case .mp3:
            bitrate = quality.bitrate ?? SongStreamQuality.HIGH.bitrate
        case .wav:
            bitrate = nil
        }

        return SongPlaybackPlan(
            method: .transcode,
            outputFormat: outputFormat.rawValue,
            bitrate: bitrate,
            reason: reason
        )
    }

    func buildPlaybackURL(
        for source: SongPlaybackSource,
        plan: SongPlaybackPlan
    ) async throws -> URL {
        var parameters: ApiParameters = [
            "id": .string(source.id),
            "format": .string(plan.outputFormat),
        ]
        if let bitrate = plan.bitrate {
            parameters["bitrate"] = .int(bitrate)
        }

        Logger.info(
            "播放方案: method=\(plan.method.rawValue), format=\(plan.outputFormat), bitrate=\(plan.bitrate ?? 0), reason=\(plan.reason.rawValue), id=\(source.id)"
        )

        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.STREAM,
            method: plan.method.rawValue,
            version: 1,
            pathSuffix: "/0\(plan.fileExtension)",
            sidOnQuery: true
        ) {
            let pairs: [ApiParametersBuilder.Parameter] = parameters.map { key, value in
                (key, value as ApiParameterValueConvertible)
            }
            for pair in pairs {
                pair
            }
        }
        return try await urlBuilder.buildUrl(api)
    }
}
