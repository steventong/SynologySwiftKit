//
//  SynologyError.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - SynologyError

/// 统一的 Synology API 错误类型
/// Unified Synology API error type
///
/// 使用示例 / Usage:
/// ```swift
/// do {
///     try await client.auth.login(...)
/// } catch SynologyError.auth(.invalidCredentials) {
///     // 处理认证失败
/// } catch SynologyError.network(.timeout) {
///     // 处理网络超时
/// }
/// ```
public enum SynologyError: Error, LocalizedError {
    /// 网络层错误
    /// Network layer errors
    case network(NetworkError)

    /// API 业务错误
    /// API business errors
    case api(SynologyApiError)

    /// 认证错误
    /// Authentication errors
    case auth(AuthError)

    /// QuickConnect 错误
    /// QuickConnect errors
    case quickConnect(QuickConnectError)

    /// 连接错误
    /// Connection errors
    case connection(ConnectionError)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case let .network(error):
            return error.errorDescription
        case let .api(error):
            return error.errorDescription
        case let .auth(error):
            return error.errorDescription
        case let .quickConnect(error):
            return error.errorDescription
        case let .connection(error):
            return error.errorDescription
        }
    }

    /// 是否是需要输入 OTP 验证码的错误（不算登录失败，需要用户提供验证码）
    /// Whether this error indicates OTP input is required (not a login failure, user needs to provide verification code)
    public var isOtpRequired: Bool {
        if case .auth(.otpRequired) = self { return true }
        return false
    }
}

// MARK: - NetworkError

extension SynologyError {
    /// 网络层错误
    /// Network layer errors
    public enum NetworkError: Error, LocalizedError {
        case invalidResponse
        case httpStatus(code: Int)
        case decodingFailed(message: String)
        case requestFailed(message: String)
        case responseEmpty
        case timeout
        case connectionFailed(underlying: Error?)

        public var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response type"
            case let .httpStatus(code):
                return "Invalid http status code: \(code)"
            case let .decodingFailed(message):
                return "Failed to decode response: \(message)"
            case let .requestFailed(message):
                return "Request failed: \(message)"
            case .responseEmpty:
                return "Response is empty"
            case .timeout:
                return "Request timeout"
            case let .connectionFailed(underlying):
                return "Connection failed: \(underlying?.localizedDescription ?? "unknown")"
            }
        }
    }
}

// MARK: - ApiError

extension SynologyError {
    /// API 业务错误
    /// API business errors
    public enum SynologyApiError: Error, LocalizedError {
        /// 操作失败
        case processFail(message: String)
        /// 幂等成功（例如重复 pin）
        case idempotentSuccess(message: String)
        /// 会话无效/过期
        case invalidSession(code: Int, message: String)
        /// API 不存在
        case apiNotExists(name: String)
        /// 业务错误
        case businessError(code: Int, message: String)
        /// 请求地址未设置
        case hostNotConfigured

        public var errorDescription: String? {
            switch self {
            case let .idempotentSuccess(message):
                return "Idempotent success: \(message)"
            case let .invalidSession(_, message):
                return "Session expired: \(message)"
            case let .apiNotExists(name):
                return "API not found: \(name)"
            case let .businessError(code, message):
                return "API error (\(code)): \(message)"
            case .hostNotConfigured:
                return "Request host not configured"
            case let .processFail(message):
                return "process fail: \(message)"
            }
        }
    }
}

// MARK: - AuthError

extension SynologyError {
    /// 认证错误
    /// Authentication errors
    public enum AuthError: Error, LocalizedError {
        /// 账号或密码错误
        case invalidCredentials
        /// 账号已禁用
        case accountDisabled
        /// 权限被拒绝
        case permissionDenied
        /// 需要两步验证
        case otpRequired
        /// 两步验证失败
        case otpFailed
        /// 强制两步验证
        case otpEnforced
        /// IP 被封锁
        case ipBlocked
        /// 密码过期（无法更改）
        case passwordExpiredCannotChange
        /// 密码过期
        case passwordExpired
        /// 必须更改密码
        case passwordMustChange
        /// 未定义错误
        case undefined(code: Int, message: String)

        public var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return Localization.text("NO_SUCH_ACCOUNT_OR_INCORRECT_PASSWORD")
            case .accountDisabled:
                return Localization.text("DISABLED_ACCOUNT")
            case .permissionDenied:
                return Localization.text("DENIED_PERMISSION")
            case .otpRequired:
                return Localization.text("AUTHENTICATION_CODE_REQUIRED")
            case .otpFailed:
                return Localization.text("AUTHENTICATION_CODE_FAILED")
            case .otpEnforced:
                return Localization.text("ENFORCE_AUTHENTICATION_WITH_CODE")
            case .ipBlocked:
                return Localization.text("BLOCKED_IP_SOURCE")
            case .passwordExpiredCannotChange:
                return Localization.text("EXPIRED_PASSWORD_CANNOT_CHANGE")
            case .passwordExpired:
                return Localization.text("EXPIRED_PASSWORD")
            case .passwordMustChange:
                return Localization.text("PASSWORD_MUST_BE_CHANGED")
            case let .undefined(_, message):
                return message
            }
        }

        /// 从错误码创建 AuthError
        /// Create AuthError from error code
        public static func fromCode(_ code: Int, message: String = "") -> AuthError {
            switch code {
            case 400: return .invalidCredentials
            case 401: return .accountDisabled
            case 402: return .permissionDenied
            case 403: return .otpRequired
            case 404: return .otpFailed
            case 406: return .otpEnforced
            case 407: return .ipBlocked
            case 408: return .passwordExpiredCannotChange
            case 409: return .passwordExpired
            case 410: return .passwordMustChange
            default: return .undefined(code: code, message: message)
            }
        }
    }
}

// MARK: - QuickConnectError

extension SynologyError {
    /// QuickConnect 错误
    /// QuickConnect errors
    public enum QuickConnectError: Error, LocalizedError {
        /// 服务器信息未找到
        case serverInfoNotFound
        /// 无效 URL
        case invalidURL
        /// 无法建立连接
        case connectionFailed

        public var errorDescription: String? {
            switch self {
            case .serverInfoNotFound:
                return "QuickConnect server info not available"
            case .invalidURL:
                return "Invalid QuickConnect URL"
            case .connectionFailed:
                return "Failed to establish QuickConnect connection"
            }
        }
    }
}

// MARK: - ConnectionError

extension SynologyError {
    /// 连接错误
    /// Connection errors
    public enum ConnectionError: Error, LocalizedError {
        /// 连接不可用
        case unavailable
        /// 未配置
        case notConfigured

        public var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Device connection not available"
            case .notConfigured:
                return "Connection not configured"
            }
        }
    }
}
