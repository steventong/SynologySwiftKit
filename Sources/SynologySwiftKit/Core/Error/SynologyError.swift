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
public enum SynologyError: Error, LocalizedError, Sendable {
    /// 网络层错误（超时、连接失败、解码失败、HTTP 状态码异常等）
    /// Network layer error (timeout, connection failure, decoding failure, HTTP status, etc.)
    case network(message: String)

    /// HTTPS 证书不受系统信任，需要用户确认后重试。
    /// The HTTPS certificate is not system-trusted and requires user approval.
    case serverCertificateUntrusted(SynologyServerCertificate)

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
        case let .serverCertificateUntrusted(certificate):
            return "The certificate presented by \(certificate.host) is not trusted."
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
        return SynologyErrorCode(rawValue: code).description
    }

    /// 从错误码创建认证错误
    /// Create auth error from error code
    public static func authError(code: Int, message: String = "") -> SynologyError {
        let localizedMessage = message.isEmpty ? authMessage(forCode: code) : message
        return .auth(code: code, message: localizedMessage)
    }
}
