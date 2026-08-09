//
//  LoginProgress.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - LoginProgress

/// 登录进度枚举，用于 AsyncStream 多次返回状态
/// Login progress enum for AsyncStream multiple status returns
public enum SynologyUserLoginProgress: Sendable {
    /// 正在获取连接地址
    /// Fetching connection address
    case connecting

    /// 正在登录认证
    /// Authenticating
    case authenticating

    /// 登录成功
    /// Login completed successfully
    case completed(result: SynologyUserLoginResult)

    /// 登录失败（携带本地化的失败描述）
    /// Login failed (with localized failure description)
    case failed(message: String)

    /// HTTPS certificate requires explicit user approval before retrying.
    case serverCertificateUntrusted(SynologyServerCertificate)

    /// 需要输入 OTP 验证码
    /// OTP verification code required
    case otpRequired

    /// session is invalid
    case invalidSession(message: String)
}
