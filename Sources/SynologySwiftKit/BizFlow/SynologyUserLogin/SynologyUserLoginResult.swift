//
//  LoginResult.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - LoginResult

/// 登录结果
/// Login result
public struct SynologyUserLoginResult: Sendable {
    /// 会话信息
    public let session: SynologySession

    /// 当前连接信息
    public let connection: SynologyConnection

    /// 服务器类型
    public let serverType: ServerType

    public init(session: SynologySession, connection: SynologyConnection, serverType: ServerType) {
        self.session = session
        self.connection = connection
        self.serverType = serverType
    }
}
