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
    /// QuickConnect request timeout (seconds)
    public let quickConnectTimeout: TimeInterval

    /// PingPong 请求超时时间 (秒)
    /// PingPong request timeout (seconds)
    public let pingpongTimeout: TimeInterval

    /// 是否启用详细的网络日志
    /// Enable verbose network logging
    public let enableNetworkLogging: Bool

    /// 日志输出目的地
    /// Logging destination
    public let logDestination: SynologyLogDestination

    /// 宿主应用可选注入的日志处理器
    /// Optional host application log handler
    public let logHandler: SynologyLogHandler?

    /// API 信息缓存有效期 (秒，默认 24 小时)
    /// API info cache validity (seconds, default: 24 hours)
    public let apiInfoCacheValidity: Int32

    /// 初始化全局配置
    /// Initialize global configuration
    /// - Parameters:
    ///   - timeoutInterval: 网络请求超时时间（秒，默认 10s）/ Network request timeout (seconds, default: 10s)
    ///   - quickConnectTimeout: QuickConnect 解析超时时间（秒，默认 10s）/ QuickConnect resolution timeout (seconds, default: 10s)
    ///   - pingpongTimeout: PingPong 检测超时时间（秒，默认 3.6s）/ PingPong check timeout (seconds, default: 3.6s)
    ///   - enableNetworkLogging: 是否启用详细网络日志（默认 true）/ Enable verbose network logging (default: true)
    ///   - logDestination: 日志输出目的地，默认 `.system` / Logging destination, default: `.system`
    ///   - logHandler: 可选日志处理器，默认 `nil` / Optional log handler, default: `nil`
    ///   - apiInfoCacheValidity: API 信息缓存有效期（秒，默认 86400s = 24h）/ API info cache validity (seconds, default: 86400s = 24h)
    public init(
        timeoutInterval: TimeInterval = 10,
        quickConnectTimeout: TimeInterval = 10,
        pingpongTimeout: TimeInterval = 3.6,
        enableNetworkLogging: Bool = true,
        logDestination: SynologyLogDestination = .system,
        logHandler: SynologyLogHandler? = nil,
        apiInfoCacheValidity: Int32 = 86400
    ) {
        self.timeoutInterval = timeoutInterval
        self.quickConnectTimeout = quickConnectTimeout
        self.pingpongTimeout = pingpongTimeout
        self.enableNetworkLogging = enableNetworkLogging
        self.logDestination = logDestination
        self.logHandler = logHandler
        self.apiInfoCacheValidity = apiInfoCacheValidity
    }
}
