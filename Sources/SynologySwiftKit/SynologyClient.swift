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
public final class SynologyClient: @unchecked Sendable {
    // MARK: - Core Services

    /// 设备连接管理
    public let deviceConnection: DeviceConnection

    /// API 客户端
    let apiClient: ApiClient

    /// API 信息管理
    public let apiInfo: ApiInfoApi
    
    /// 全局配置
    public let config: SynologyConfig

    // MARK: - API Modules

    /// AudioStation API
    public let audioStation: AudioStationApi

    /// FileStation API
    public let fileStation: FileStationApi

    /// 认证 API
    public let auth: AuthApi

    /// QuickConnect API
    public let quickConnect: QuickConnectApi

    /// DSM 信息 API
    public let dsmInfo: DsmInfoApi

    /// 加密 API
    public let encryption: EncryptionApi

    // MARK: - Business Flows (Lazy initialized for performance if needed, but currently pre-warmed)

    /// 用户登录流程
    public let userLogin: SynologyUserLogin

    /// 设备连接检查
    public let checkConnection: CheckDeviceConnection

    /// 查询所有歌曲
    public let queryAllSongs: QueryAllSongs

    // MARK: - Initialization

    /// 初始化 Synology 客户端
    /// - Parameter config: 全局配置 (默认为 SynologyConfig.default)
    public init(config: SynologyConfig = .default) {
        self.config = config
        
        let connection = DeviceConnection()
        let client = ApiClient(connectionProvider: connection)
        let info = ApiInfoApi(apiClient: client, connectionProvider: connection)

        self.deviceConnection = connection
        self.apiClient = client
        self.apiInfo = info

        // 注入 API 信息提供者
        client.apiInfoProvider = info

        // 初始化各个 API 模块
        self.audioStation = AudioStationApi(apiClient: client)
        self.fileStation = FileStationApi(apiClient: client)
        self.auth = AuthApi(apiClient: client)
        self.quickConnect = QuickConnectApi(deviceConnection: connection)
        self.dsmInfo = DsmInfoApi(apiClient: client)
        self.encryption = EncryptionApi(apiClient: client)

        // 初始化流程类
        self.userLogin = SynologyUserLogin(deviceConnection: connection, apiInfoApi: info, apiClient: client)
        self.checkConnection = CheckDeviceConnection(deviceConnection: connection, apiInfoApi: info, apiClient: client)
        self.queryAllSongs = QueryAllSongs(apiClient: client)
    }
}
