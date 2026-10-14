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
public enum ConnectionCheckProgress: Sendable {
    /// 正在检查连接
    /// Checking connection
    case checking

    /// 连接成功
    /// Connection successful
    case success(connection: SynologyConnection)

    /// HTTPS certificate requires explicit user approval.
    case serverCertificateUntrusted(SynologyServerCertificate)

    /// Connection failed
    case failed(message: String)
}
