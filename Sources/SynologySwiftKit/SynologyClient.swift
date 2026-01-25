//
//  SynologyClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - SynologyClient

/// Synology 服务容器（依赖注入中心）
/// Synology service container (dependency injection center)
///
/// 统一的服务入口，管理所有依赖和 API 模块。
/// Unified service entry point, managing all dependencies and API modules.
///
/// 使用示例 / Usage:
/// ```swift
/// let client = SynologyClient()
/// try await client.audioStation.songList(limit: 100)
/// ```
public final class SynologyClient {
    // MARK: - Core Services

    /// 设备连接管理
    /// Device connection manager
    public let deviceConnection: DeviceConnection

    /// API 客户端（internal，不暴露给外部）
    /// API client (internal, not exposed externally)
    let apiClient: ApiClient

    /// API 信息管理
    /// API information manager
    public let apiInfo: ApiInfoApi

    // MARK: - API Modules

    /// AudioStation API
    public lazy var audioStation: AudioStationApi = { AudioStationApi(apiClient: apiClient) }()

    /// 认证 API
    /// Authentication API
    public lazy var auth: AuthApi = { AuthApi(apiClient: apiClient) }()

    /// QuickConnect API
    public lazy var quickConnect: QuickConnectApi = { QuickConnectApi(deviceConnection: deviceConnection) }()

    /// DSM 信息 API
    /// DSM info API
    public lazy var dsmInfo: DsmInfoApi = { DsmInfoApi(apiClient: apiClient) }()

    /// 加密 API
    /// Encryption API
    public lazy var encryption: EncryptionApi = { EncryptionApi(apiClient: apiClient) }()

    // MARK: - Business Flows

    /// 用户登录流程
    /// User login flow
    public lazy var userLogin: SynologyUserLogin = {
        SynologyUserLogin(deviceConnection: deviceConnection, apiInfoApi: apiInfo, apiClient: apiClient)
    }()

    /// 设备连接检查
    /// Device connection check
    public lazy var checkConnection: CheckDeviceConnection = {
        CheckDeviceConnection(deviceConnection: deviceConnection, apiInfoApi: apiInfo, apiClient: apiClient
        )
    }()

    // MARK: - Initialization

    /// 初始化 Synology 客户端
    /// Initialize Synology client
    public init() {
        deviceConnection = DeviceConnection()
        apiClient = ApiClient(connectionProvider: deviceConnection)
        apiInfo = ApiInfoApi(apiClient: apiClient)

        // 设置延迟依赖以解决循环依赖
        apiClient.apiInfoProvider = apiInfo
    }
}
