//
//  ConnectionCheckProgress.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/30.
//

import Foundation

// MARK: - ConnectionCheckProgress

/// 连接检查进度枚举，用于 AsyncStream 多次返回状态
/// Connection check progress enum for AsyncStream multiple status returns
public enum ConnectionCheckProgress: Sendable {
    /// 正在检查现有连接
    /// Checking existing connection
    case checkingExistingConnection(url: String)
    
    /// 现有连接 Ping 成功
    /// Existing connection ping succeeded
    case existingConnectionAvailable(type: ConnectionType, url: String)
    
    /// 正在通过 QuickConnect 获取新连接
    /// Fetching new connection via QuickConnect
    case fetchingQuickConnect(quickConnectId: String)
    
    /// QuickConnect 获取成功，正在验证
    /// QuickConnect fetched, validating connection
    case quickConnectFetched(type: ConnectionType, url: String)
    
    /// 正在查询 API 信息
    /// Querying API information
    case queryingApiInfo
    
    /// 正在查询 AudioStation 信息
    /// Querying AudioStation information
    case queryingAudioStation
    
    /// 连接检查成功
    /// Connection check succeeded
    case success(type: ConnectionType, url: String, audioStationInfo: AudioStationInfo)
    
    /// 连接检查失败
    /// Connection check failed
    case failed(reason: ConnectionCheckFailureReason)
    
    /// 需要重新登录
    /// Login required
    case loginRequired(reason: LoginRequiredReason)
}

// MARK: - ConnectionCheckFailureReason

/// 连接检查失败原因
/// Connection check failure reason
public enum ConnectionCheckFailureReason: Sendable {
    /// 域名 Ping 失败
    /// Custom domain ping failed
    case customDomainPingFailed(url: String)
    
    /// QuickConnect 获取连接失败
    /// QuickConnect fetch connection failed
    case quickConnectFetchFailed
    
    /// DSM 信息查询失败
    /// DSM info query failed
    case dsmInfoQueryFailed(error: String)
    
    /// AudioStation 信息查询失败
    /// AudioStation info query failed
    case audioStationQueryFailed(error: String)
    
    /// API 信息查询失败
    /// API info query failed
    case apiInfoQueryFailed(error: String)
}

// MARK: - LoginRequiredReason

/// 需要登录的原因
/// Reason for login required
public enum LoginRequiredReason: Sendable {
    /// 没有保存的登录服务器信息
    /// No saved login server information
    case noLoginServer
    
    /// 会话已失效
    /// Session is invalid
    case sessionInvalid
}
