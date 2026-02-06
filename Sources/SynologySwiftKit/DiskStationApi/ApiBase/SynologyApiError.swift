//
//  SynologyApiError.swift
//  SynologySwiftKit
//
//  Created by Steven on 05/02/2026.
//

import Foundation

// MARK: - SynologyApiError (仅用于 JSON 解码)

/// Synology API 原始错误结构（用于 JSON 解码）
/// Synology API raw error structure (for JSON decoding only)
///
/// 服务器返回格式：`{ "code": 1002, "errors": [1006] }`
public struct SynologyApiError: Error, Decodable, Sendable {
    /// 主错误码
    public let code: Int
    /// 子错误码列表
    public let errors: [Int]

    /// 未知错误
    public static let unknown = SynologyApiError(code: -1, errors: [])

    // MARK: - Decodable

    enum CodingKeys: String, CodingKey {
        case code
        case errors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        errors = try container.decodeIfPresent([Int].self, forKey: .errors) ?? []
    }

    public init(code: Int, errors: [Int] = []) {
        self.code = code
        self.errors = errors
    }

    // MARK: - Conversion

    /// 转换为 SynologyError
    /// Convert to SynologyError
    public func toSynologyError() -> SynologyError {
        // Session 相关错误
        switch code {
        case 105, 106, 107, 119:
            let message = SynologyErrorCodeMapper.description(for: code) ?? "Session error (code: \(code))"
            return .api(.invalidSession(code: code, message: message))
        case 102:
            return .api(.apiNotExists(name: "unknown"))
        default:
            let message = SynologyErrorCodeMapper.description(for: code) ?? "errorCode = \(code)"
            return .api(.businessError(code: code, message: message))
        }
    }
}
