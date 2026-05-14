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
struct SynologyApiError: Error, Decodable, Sendable {
    /// 主错误码
    let code: Int
    /// 子错误码列表
    let errors: [Int]

    /// 未知错误
    static let unknown = SynologyApiError(code: -1, errors: [])

    // MARK: - Decodable

    enum CodingKeys: String, CodingKey {
        case code
        case errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        errors = try container.decodeIfPresent([Int].self, forKey: .errors) ?? []
    }

    init(code: Int, errors: [Int] = []) {
        self.code = code
        self.errors = errors
    }

    // MARK: - Conversion

    /// 将当前实例转换为统一的 SynologyError
    /// Convert to unified SynologyError
    ///
    /// - Session 相关错误码（106/107/119）→ `.sessionExpired`
    ///   Session-related codes (106/107/119) → `.sessionExpired`
    /// - 权限不足错误码（105）→ `.api`
    ///   Permission denied code (105) → `.api`
    /// - 120-149 保留错误码 → `.api`
    ///   Reserved codes 120-149 → `.api`
    /// - 其余错误码通过 `SynologyErrorCode` 获取描述后 → `.api`
    ///   Other codes → `.api` with description from `SynologyErrorCode`
    func toSynologyError() -> SynologyError {
        SynologyErrorCode(rawValue: code).toSynologyError()
    }

    /// 仅凭错误码构造对应的 SynologyError（无需完整 SynologyApiError 实例）
    /// Create a SynologyError directly from an error code
    /// - Parameter code: API 业务错误码 / API business error code
    static func toSynologyError(from code: Int) -> SynologyError {
        SynologyErrorCode(rawValue: code).toSynologyError()
    }
}
