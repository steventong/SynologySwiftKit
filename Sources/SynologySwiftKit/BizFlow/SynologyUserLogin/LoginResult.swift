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
public struct LoginResult: Sendable {
    /// 会话 ID
    public let sid: String
    
    /// 设备 ID
    public let did: String?
    
    /// 连接类型
    public let connectionType: ConnectionType
    
    /// 连接 URL
    public let connectionUrl: String
    
    /// 服务器类型
    public let serverType: ServerType
    
    public init(sid: String, did: String?, connectionType: ConnectionType, connectionUrl: String, serverType: ServerType) {
        self.sid = sid
        self.did = did
        self.connectionType = connectionType
        self.connectionUrl = connectionUrl
        self.serverType = serverType
    }
}
