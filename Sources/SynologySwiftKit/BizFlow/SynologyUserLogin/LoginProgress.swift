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

    /// 正在检查已保存的连接地址
    /// Checking saved connection URL
    case checkingSavedConnection(url: String)

    /// 已保存的连接地址不可达，将通过 QuickConnect 重新获取
    /// Saved connection unreachable, falling back to QuickConnect
    case savedConnectionUnreachable(url: String)

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



// MARK: - LoginError (Deprecated - Use SynologyError)

/// 登录错误 - 建议使用 SynologyError
/// Login error - prefer using SynologyError
/// @available(*, deprecated, message: "Use SynologyError instead")
public typealias LoginError = SynologyError

