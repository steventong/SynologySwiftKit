//
//  ConnectionCheckProgress.swift
//  SynologySwiftKit
//
//  Created by Steven on 15/02/2026.
//

import Foundation

// MARK: - Connection Check Progress

/// 连接检查进度
/// Connection check progress (Simplified)
public enum CheckDeviceConnectionProgress: Sendable {
    /// 正在检查连接
    /// Checking connection
    case checking

    /// 连接成功
    /// Connection successful
    /// cached 表示不需要再次登录用户。
    /// cached = false 表示地址切换了，需要重新登录的。
    case success(type: ConnectionType, url: String, cached: Bool)

    /// Connection failed
    case failed(message: String)
}
