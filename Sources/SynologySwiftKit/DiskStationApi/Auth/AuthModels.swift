//
//  AuthModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - AuthResult

/// 登录结果模型（由 `SYNO.API.Auth login` 接口返回）
/// Login result model (returned by `SYNO.API.Auth login`)
public struct AuthResult: Decodable {
    /// 设备 ID（启用设备令牌时服务器返回，用于免密信任登录）
    /// Device ID (returned by server when device token is enabled, for trusted login)
    public var did: String?

    /// 是否为 Portal 端口（DSM 反向代理相关）
    /// Whether this is a portal port (related to DSM reverse proxy)
    public var isPortalPort: Bool

    /// 会话 ID（后续请求需携带）
    /// Session ID (required for subsequent requests)
    public var sid: String

    /// Synology Token（可选，部分 API 需要）
    /// Synology token (optional, required by some APIs)
    public var synotoken: String?

    enum CodingKeys: String, CodingKey {
        case did
        case isPortalPort = "is_portal_port"
        case sid
        case synotoken
    }
}
