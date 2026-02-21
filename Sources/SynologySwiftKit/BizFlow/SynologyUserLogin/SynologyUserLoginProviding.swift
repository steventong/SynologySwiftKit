//
//  File.swift
//  SynologySwiftKit
//
//  Created by Steven on 21/02/2026.
//

import Foundation

public protocol SynologyUserLoginProviding {
    /// 通过密码登录（AsyncStream 版本）
    /// Login with password (AsyncStream version)
    /// - Parameters:
    ///   - server: QuickConnect ID 或自定义域名
    ///   - enableHttps: 是否启用 HTTPS
    ///   - username: 用户名
    ///   - password: 密码
    ///   - otpCode: 可选的 OTP 代码
    ///   - shouldSavePassword: 是否保存密码（默认为 true）
    /// - Returns: AsyncStream 返回登录进度
    func login(server: String, enableHttps: Bool, username: String, password: String, otpCode: String?, shouldSavePassword: Bool) -> AsyncStream<SynologyUserLoginProgress>

    /// 刷新登录信息，静默登录
    func login(continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) -> AsyncStream<SynologyUserLoginProgress>
}
