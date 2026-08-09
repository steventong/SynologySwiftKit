//
//  SynologyErrorCode.swift
//  SynologySwiftKit
//
//  Created by SynologySwiftKit on 2026/05/10.
//

import Foundation

// MARK: - SynologyErrorCode

/// Synology API 原始错误码
/// Synology API raw error code
public struct SynologyErrorCode: RawRepresentable, Equatable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // MARK: - Common Error Codes

    /// 未知错误 / Unknown error.
    public static let unknown = SynologyErrorCode(rawValue: 100)
    /// 无效的参数 / Invalid parameter.
    public static let invalidParameter = SynologyErrorCode(rawValue: 101)
    /// 请求的 API 不存在 / The requested API does not exist.
    public static let apiDoesNotExist = SynologyErrorCode(rawValue: 102)
    /// 请求的方法不存在 / The requested method does not exist.
    public static let methodDoesNotExist = SynologyErrorCode(rawValue: 103)
    /// 请求的版本不支持该功能 / The requested version does not support the functionality.
    public static let versionDoesNotSupport = SynologyErrorCode(rawValue: 104)
    /// 登录会话没有权限 / The logged in session does not have permission.
    public static let sessionPermissionDenied = SynologyErrorCode(rawValue: 105)
    /// 会话超时 / Session timeout.
    public static let sessionTimeout = SynologyErrorCode(rawValue: 106)
    /// 会话被重复登录中断 / Session interrupted by duplicate login.
    public static let sessionInterrupted = SynologyErrorCode(rawValue: 107)
    /// 上传文件失败 / Failed to upload the file.
    public static let uploadFailed = SynologyErrorCode(rawValue: 108)
    /// 网络连接不稳定或系统繁忙 / The network connection is unstable or the system is busy.
    public static let networkUnstable109 = SynologyErrorCode(rawValue: 109)
    public static let networkUnstable110 = SynologyErrorCode(rawValue: 110)
    public static let networkUnstable111 = SynologyErrorCode(rawValue: 111)
    public static let preserve112 = SynologyErrorCode(rawValue: 112)
    public static let preserve113 = SynologyErrorCode(rawValue: 113)
    /// 丢失此 API 的参数 / Lost parameters for this API.
    public static let lostParameters = SynologyErrorCode(rawValue: 114)
    /// 不允许上传文件 / Not allowed to upload a file.
    public static let notAllowedToUpload = SynologyErrorCode(rawValue: 115)
    /// 演示站点不允许执行 / Not allowed to perform for a demo site.
    public static let notAllowedForDemo = SynologyErrorCode(rawValue: 116)
    public static let networkUnstable117 = SynologyErrorCode(rawValue: 117)
    public static let networkUnstable118 = SynologyErrorCode(rawValue: 118)
    /// 无效的会话 / Invalid session.
    public static let invalidSession = SynologyErrorCode(rawValue: 119)
    /// 请求源 IP 与登录 IP 不匹配 / Request source IP does not match the login IP.
    public static let sourceIPMismatch = SynologyErrorCode(rawValue: 150)

    // MARK: - Auth Error Codes

    public static let noSuchAccountOrIncorrectPassword = SynologyErrorCode(rawValue: 400)
    public static let disabledAccount = SynologyErrorCode(rawValue: 401)
    public static let deniedPermission = SynologyErrorCode(rawValue: 402)
    public static let authenticationCodeRequired = SynologyErrorCode(rawValue: 403)
    public static let authenticationCodeFailed = SynologyErrorCode(rawValue: 404)
    public static let portalPortInvalid = SynologyErrorCode(rawValue: 405)
    public static let enforceAuthenticationWithCode = SynologyErrorCode(rawValue: 406)
    public static let blockedIPSource = SynologyErrorCode(rawValue: 407)
    public static let expiredPasswordCannotChange = SynologyErrorCode(rawValue: 408)
    public static let expiredPassword = SynologyErrorCode(rawValue: 409)
    public static let passwordMustBeChanged = SynologyErrorCode(rawValue: 410)
    public static let accountLocked = SynologyErrorCode(rawValue: 411)

    // MARK: - Descriptions

    /// 获取默认描述
    /// Get default description
    public var description: String {
        switch self {
        case .unknown: return "Unknown error."
        case .invalidParameter: return "Invalid parameter."
        case .apiDoesNotExist: return "The requested API does not exist."
        case .methodDoesNotExist: return "The requested method does not exist."
        case .versionDoesNotSupport: return "The requested version does not support the functionality."
        case .sessionPermissionDenied: return "The logged in session does not have permission."
        case .sessionTimeout: return "Session timeout."
        case .sessionInterrupted: return "Session interrupted by duplicate login."
        case .uploadFailed: return "Failed to upload the file."
        case .networkUnstable109, .networkUnstable110, .networkUnstable111, .networkUnstable117, .networkUnstable118:
            return "The network connection is unstable or the system is busy."
        case .preserve112, .preserve113: return "Preserve for other purpose."
        case .lostParameters: return "Lost parameters for this API."
        case .notAllowedToUpload: return "Not allowed to upload a file."
        case .notAllowedForDemo: return "Not allowed to perform for a demo site."
        case .invalidSession: return "Invalid session."
        case .sourceIPMismatch: return "Request source IP does not match the login IP."

        case .noSuchAccountOrIncorrectPassword: return Localization.text("NO_SUCH_ACCOUNT_OR_INCORRECT_PASSWORD")
        case .disabledAccount: return Localization.text("DISABLED_ACCOUNT")
        case .deniedPermission: return Localization.text("DENIED_PERMISSION")
        case .authenticationCodeRequired: return Localization.text("AUTHENTICATION_CODE_REQUIRED")
        case .authenticationCodeFailed: return Localization.text("AUTHENTICATION_CODE_FAILED")
        case .portalPortInvalid: return Localization.text("PORTAL_PORT_INVALID")
        case .enforceAuthenticationWithCode: return Localization.text("ENFORCE_AUTHENTICATION_WITH_CODE")
        case .blockedIPSource: return Localization.text("BLOCKED_IP_SOURCE")
        case .expiredPasswordCannotChange: return Localization.text("EXPIRED_PASSWORD_CANNOT_CHANGE")
        case .expiredPassword: return Localization.text("EXPIRED_PASSWORD")
        case .passwordMustBeChanged: return Localization.text("PASSWORD_MUST_BE_CHANGED")
        case .accountLocked: return Localization.text("ACCOUNT_LOCKED")

        default:
            if (120...149).contains(rawValue) {
                return "Preserve for other purpose."
            }
            return "errorCode = \(rawValue)"
        }
    }

    // MARK: - Conversion

    /// 将错误码转换为 SDK 的核心错误类型
    /// Convert error code to SDK's core error type
    public func toSynologyError() -> SynologyError {
        switch self {
        case .sessionTimeout, .sessionInterrupted, .invalidSession:
            return .sessionExpired(code: rawValue, message: description)
        case _ where (400...411).contains(rawValue):
            return .auth(code: rawValue, message: description)
        default:
            return .api(code: rawValue, message: description)
        }
    }
}
