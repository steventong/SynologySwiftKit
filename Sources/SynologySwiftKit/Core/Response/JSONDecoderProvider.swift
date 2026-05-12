//
//  JSONDecoderProvider.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - JSONDecoderProvider

/// JSON 解码器提供者（单例复用）
/// JSON decoder provider (singleton for reuse)
///
/// 避免每次网络请求都创建新的 JSONDecoder 实例
/// Avoids creating new JSONDecoder instance for each network request
enum JSONDecoderProvider {
    /// 共享解码器实例
    /// Shared decoder instance
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        // 可根据需要配置日期解码策略
        // Configure date decoding strategy as needed
        // decoder.dateDecodingStrategy = .iso8601
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
