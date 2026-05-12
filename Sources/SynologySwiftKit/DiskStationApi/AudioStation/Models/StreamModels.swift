//
//  StreamModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2025/2/8.
//

import Foundation

// MARK: - StreamMethodEnum

/// 音频流播放方式枚举
/// Audio streaming method enum
public enum StreamMethodEnum: Sendable {
    /// 直接流（原始音频流，不转码）
    /// Direct stream (raw audio, no transcoding)
    case STREAM

    /// 转码流（服务器转码为兼容格式后流传输）
    /// Transcode stream (server transcodes to compatible format before streaming)
    case TRANSCODE
}
