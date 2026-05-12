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
    /// usedCachedConnection 表示不需要再次登录用户。
    /// usedCachedConnection = false 表示地址切换了，需要重新登录。
    case success(connection: SynologyConnection, usedCachedConnection: Bool)

    /// Connection failed
    case failed(message: String)
}
