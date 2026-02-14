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
    func getCurrentConnectionUrl() async -> (type: ConnectionType, url: String)?

    /// 获取登录会话信息
    /// Get login session information
    func getLoginSession() async -> (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)?

    /// 获取登录服务器配置
    /// Get login server configuration
    func getLoginServer() async -> (server: String, isEnableHttps: Bool)?

    /// 获取会话用户名
    /// Get session username
    func getSessionUsername() async -> String?

    // MARK: - Write Methods

    /// 更新登录会话
    /// Update login session
    func updateLoginSession(username: String, sid: String, did: String?) async

    /// 更新当前连接 URL
    /// Update current connection URL
    func updateCurrentConnectionUrl(type: ConnectionType, url: String) async

    /// 更新登录偏好设置
    /// Update login preferences
    func updateLoginPreferences(server: String, isEnableHttps: Bool) async

    /// 移除登录会话
    /// Remove login session
    func removeLoginSession() async

    // MARK: - Credential Methods

    /// 保存登录凭据到 Keychain
    /// Save login credentials to Keychain
    /// - Parameters:
    ///   - server: 服务器地址（QuickConnect ID 或自定义域名）/ Server address
    ///   - username: 用户名 / Username
    ///   - password: 密码 / Password
    ///   - isEnableHttps: 是否启用 HTTPS (可选) / Enable HTTPS (optional)
    func saveCredentials(server: String, username: String, password: String, isEnableHttps: Bool?) async

    /// 读取已保存的登录凭据（供 App 登录页展示）
    /// Read saved login credentials (for App login page display)
    /// - Returns: 凭据元组（server, username, password, isEnableHttps），如果不存在则返回 nil
    func getCredentials() async -> (server: String, username: String, password: String, isEnableHttps: Bool?)?

    /// 删除已保存的登录凭据
    /// Remove saved login credentials
    func removeCredentials() async
    
    /// 获取持久化的 Device ID (用于登录参数)
    /// Get persistent Device ID (for login parameters)
    func getPersistentDeviceId() async -> String?
    
    /// 获取设备名称 (持久化)
    /// Get Device Name (Persistent)
    func getDeviceName() async -> String
}
