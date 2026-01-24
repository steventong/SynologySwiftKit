//
//  DeviceConnectionProviding.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/5/2.
//

import Foundation

// MARK: - DeviceConnectionProviding Protocol

/// 设备连接管理协议
/// Device connection management protocol
///
/// 定义设备连接、会话管理和登录偏好的接口。
/// 实现依赖注入模式，提高可测试性。
///
/// Defines interfaces for device connection, session management and login preferences.
/// Implements dependency injection pattern for better testability.
public protocol DeviceConnectionProviding {

    // MARK: - Read Methods

    /// 获取当前连接 URL
    /// Get current connection URL
    func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)?

    /// 获取登录会话信息
    /// Get login session information
    func getLoginSession() -> (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)?

    /// 获取登录服务器配置
    /// Get login server configuration
    func getLoginServer() -> (server: String, isEnableHttps: Bool)?

    /// 获取会话用户名
    /// Get session username
    func getSessionUsername() -> String?

    // MARK: - Write Methods

    /// 更新登录会话
    /// Update login session
    func updateLoginSession(username: String, sid: String, did: String?)

    /// 更新当前连接 URL
    /// Update current connection URL
    func updateCurrentConnectionUrl(type: ConnectionType, url: String)

    /// 更新登录偏好设置
    /// Update login preferences
    func updateLoginPreferences(server: String, isEnableHttps: Bool)

    /// 移除登录会话
    /// Remove login session
    func removeLoginSession()
}
