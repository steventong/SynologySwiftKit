//
//  SynologyConfig.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// Synology 客户端全局配置
/// Global configuration for Synology Client
public struct SynologyConfig: Sendable {
    /// 默认单例配置
    public static let `default` = SynologyConfig()

    /// 网络请求超时时间 (秒)
    /// Network request timeout (seconds)
    public let timeoutInterval: TimeInterval

    /// QuickConnect 请求超时时间 (秒)
    public let quickConnectTimeout: TimeInterval

    /// PingPong 请求超时时间 (秒)
    public let pingpongTimeout: TimeInterval

    /// 是否启用详细的网络日志
    /// Enable verbose network logging
    public let enableNetworkLogging: Bool

    /// API 缓存有效期 (秒) (默认 24 小时)
    public let apiInfoCacheValidity: Int32

    /// 初始化配置
    public init(timeoutInterval: TimeInterval = 10, quickConnectTimeout: TimeInterval = 10, pingpongTimeout: TimeInterval = 3.6, enableNetworkLogging: Bool = true, apiInfoCacheValidity: Int32 = 86400) {
        self.timeoutInterval = timeoutInterval
        self.quickConnectTimeout = quickConnectTimeout
        self.pingpongTimeout = pingpongTimeout
        self.enableNetworkLogging = enableNetworkLogging
        self.apiInfoCacheValidity = apiInfoCacheValidity
    }
}
