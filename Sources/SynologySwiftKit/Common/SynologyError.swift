//
//  SynologyError.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - SynologyError

/// 统一的 Synology API 错误类型（扁平化）
/// Unified Synology API error type (flattened)
///
/// 使用示例 / Usage:
/// ```swift
/// do {
///     try await client.auth.login(...)
/// } catch SynologyError.auth(code: 403, _) {
///     // OTP 验证码
/// } catch SynologyError.sessionExpired {
///     // Session 过期
/// }
/// ```
public enum SynologyError: Error, LocalizedError {
    /// 网络层错误（超时、连接失败、解码失败、HTTP 状态码异常等）
    /// Network layer error (timeout, connection failure, decoding failure, HTTP status, etc.)
    case network(message: String)

    /// API 业务错误（带错误码）
    /// API business error (with error code)
    case api(code: Int, message: String)

    /// Session 过期/无效
    /// Session expired or invalid
    case sessionExpired(code: Int, message: String)

    /// 认证错误（带错误码，通过 authMessage(forCode:) 获取本地化消息）
    /// Authentication error (with error code, use authMessage(forCode:) for localized message)
    case auth(code: Int, message: String)


    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case let .network(message):
            return message
        case let .api(code, message):
            return "API error (\(code)): \(message)"
        case let .sessionExpired(_, message):
            return "Session expired: \(message)"
        case let .auth(_, message):
            return message
        }
    }
}

// MARK: - Auth Error Code Mapping

extension SynologyError {
    /// 认证错误码 → 本地化消息
    /// Auth error code → localized message
    public static func authMessage(forCode code: Int) -> String {
        switch code {
        case 400: return Localization.text("NO_SUCH_ACCOUNT_OR_INCORRECT_PASSWORD")
        case 401: return Localization.text("DISABLED_ACCOUNT")
        case 402: return Localization.text("DENIED_PERMISSION")
        case 403: return Localization.text("AUTHENTICATION_CODE_REQUIRED")
        case 404: return Localization.text("AUTHENTICATION_CODE_FAILED")
        case 406: return Localization.text("ENFORCE_AUTHENTICATION_WITH_CODE")
        case 407: return Localization.text("BLOCKED_IP_SOURCE")
        case 408: return Localization.text("EXPIRED_PASSWORD_CANNOT_CHANGE")
        case 409: return Localization.text("EXPIRED_PASSWORD")
        case 410: return Localization.text("PASSWORD_MUST_BE_CHANGED")
        default: return "Auth error (code: \(code))"
        }
    }

    /// 从错误码创建认证错误
    /// Create auth error from error code
    public static func authError(code: Int, message: String = "") -> SynologyError {
        let localizedMessage = message.isEmpty ? authMessage(forCode: code) : message
        return .auth(code: code, message: localizedMessage)
    }
}
