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
public enum LoginProgress: Sendable {
    /// 登录开始
    /// Login started
    case started(server: String)
    
    /// 正在获取 QuickConnect 连接
    /// Fetching QuickConnect connection
    case fetchingQuickConnect
    
    /// QuickConnect 获取成功
    /// QuickConnect fetched successfully
    case quickConnectFetched(type: ConnectionType, url: String)
    
    /// 正在更新 API 信息
    /// Updating API information
    case updatingApiInfo
    
    /// 正在执行用户登录
    /// Performing user login
    case authenticating(serverType: ServerType)
    
    /// 登录成功
    /// Login succeeded
    case loginSuccess(result: LoginResult)
    
    /// 正在验证 AudioStation
    /// Verifying AudioStation
    case verifyingAudioStation
    
    /// 登录流程完成
    /// Login flow completed
    case completed(result: LoginResult)
    
    /// 登录失败
    /// Login failed
    case failed(error: LoginError)
}

// MARK: - ServerType

/// 服务器类型
/// Server type
public enum ServerType: Sendable {
    /// QuickConnect ID
    case quickConnectId
    
    /// 自定义域名
    /// Custom domain
    case customDomain
}

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

// MARK: - LoginError

/// 登录错误
/// Login error
public enum LoginError: Error, Sendable {
    /// 连接不可用
    /// Connection unavailable
    case connectionUnavailable
    
    /// QuickConnect 获取失败
    /// QuickConnect fetch failed
    case quickConnectFetchFailed(message: String)
    
    /// 认证失败
    /// Authentication failed
    case authenticationFailed(message: String)
    
    /// API 信息获取失败
    /// API info fetch failed
    case apiInfoFetchFailed(message: String)
    
    /// AudioStation 验证失败
    /// AudioStation verification failed
    case audioStationVerificationFailed(message: String)
    
    /// 底层错误
    /// Underlying error
    case underlying(Error)
}
