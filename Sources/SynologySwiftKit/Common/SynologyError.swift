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
    case api(ApiError)

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
        case .network(let error):
            return error.errorDescription
        case .api(let error):
            return error.errorDescription
        case .auth(let error):
            return error.errorDescription
        case .quickConnect(let error):
            return error.errorDescription
        case .connection(let error):
            return error.errorDescription
        }
    }
}

// MARK: - NetworkError

extension SynologyError {

    /// 网络层错误
    /// Network layer errors
    public enum NetworkError: Error, LocalizedError {
        /// SSL 连接失败
        case sslFailed(String)
        /// 域名解析失败
        case hostNotFound(String)
        /// 请求超时
        case timeout
        /// 连接失败
        case connectionFailed(underlying: Error)
        /// 无效响应
        case invalidResponse
        /// HTTP 状态码错误
        case httpError(statusCode: Int)
        /// 解码错误
        case decodingError(Error)
        /// 无效 URL
        case invalidURL(String)
        /// 响应为空
        case responseEmpty

        public var errorDescription: String? {
            switch self {
            case .sslFailed(let msg):
                return "SSL connection failed: \(msg)"
            case .hostNotFound(let msg):
                return "Host not found: \(msg)"
            case .timeout:
                return "Request timeout"
            case .connectionFailed(let error):
                return "Connection failed: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid server response"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .decodingError(let error):
                return "Data parsing error: \(error.localizedDescription)"
            case .invalidURL(let url):
                return "Invalid URL: \(url)"
            case .responseEmpty:
                return "Server response is empty"
            }
        }
    }
}

// MARK: - ApiError

extension SynologyError {

    /// API 业务错误
    /// API business errors
    public enum ApiError: Error, LocalizedError {
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
            case .invalidSession(_, let message):
                return "Session expired: \(message)"
            case .apiNotExists(let name):
                return "API not found: \(name)"
            case .businessError(let code, let message):
                return "API error (\(code)): \(message)"
            case .hostNotConfigured:
                return "Request host not configured"
            }
        }

        /// 是否为会话过期错误
        public var isSessionExpired: Bool {
            if case .invalidSession = self { return true }
            return false
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
                return NSLocalizedString(
                    "NO_SUCH_ACCOUNT_OR_INCORRECT_PASSWORD", comment: "Invalid credentials")
            case .accountDisabled:
                return NSLocalizedString("DISABLED_ACCOUNT", comment: "Account disabled")
            case .permissionDenied:
                return NSLocalizedString("DENIED_PERMISSION", comment: "Permission denied")
            case .otpRequired:
                return NSLocalizedString("AUTHENTICATION_CODE_REQUIRED", comment: "OTP required")
            case .otpFailed:
                return NSLocalizedString("AUTHENTICATION_CODE_FAILED", comment: "OTP failed")
            case .otpEnforced:
                return NSLocalizedString(
                    "ENFORCE_AUTHENTICATION_WITH_CODE", comment: "OTP enforced")
            case .ipBlocked:
                return NSLocalizedString("BLOCKED_IP_SOURCE", comment: "IP blocked")
            case .passwordExpiredCannotChange:
                return NSLocalizedString(
                    "EXPIRED_PASSWORD_CANNOT_CHANGE", comment: "Password expired")
            case .passwordExpired:
                return NSLocalizedString("EXPIRED_PASSWORD", comment: "Password expired")
            case .passwordMustChange:
                return NSLocalizedString(
                    "PASSWORD_MUST_BE_CHANGED", comment: "Password must change")
            case .undefined(_, let message):
                return message
            }
        }

        /// 是否需要两步验证
        public var requiresOTP: Bool {
            switch self {
            case .otpRequired, .otpEnforced: return true
            default: return false
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
        /// 连接信息未找到
        case connectionInfoNotFound
        /// 无效 URL
        case invalidURL

        public var errorDescription: String? {
            switch self {
            case .serverInfoNotFound:
                return "QuickConnect server info not available"
            case .connectionInfoNotFound:
                return "Device connection info not available"
            case .invalidURL:
                return "Invalid QuickConnect URL"
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

// MARK: - Convenience Extensions

extension SynologyError {

    /// 是否为会话过期错误
    public var isSessionExpired: Bool {
        if case .api(let error) = self, error.isSessionExpired { return true }
        return false
    }

    /// 是否为网络错误
    public var isNetworkError: Bool {
        if case .network = self { return true }
        return false
    }

    /// 是否需要两步验证
    public var requiresOTP: Bool {
        if case .auth(let error) = self, error.requiresOTP { return true }
        return false
    }
}
