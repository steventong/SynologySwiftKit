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
public final class SynologyClient {
    // MARK: - Core Services

    /// API 客户端
    let apiClient: ApiClient

    /// 全局配置
    public let config: SynologyConfig

    /// 设备连接管理
    public let deviceConnection: DeviceConnection

    /// API 信息管理
    public let apiInfo: ApiInfoApi

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

    /// PingPong
    public let pingpong: PingPong

    // MARK: - Initialization

    /// 初始化 Synology 客户端
    /// - Parameter config: 全局配置 (默认为 SynologyConfig.default)
    public init(config: SynologyConfig = .default) {
        self.config = config

        let connection = DeviceConnection()
        let client = ApiClient(connectionProvider: connection)
        let info = ApiInfoApi(apiClient: client, connectionProvider: connection, cacheValidity: config.apiInfoCacheValidity)
        let pingpong = PingPong(apiClient: client, timeout: config.pingpongTimeout)

        deviceConnection = connection
        apiClient = client
        apiInfo = info
        self.pingpong = pingpong

        // 注入 API 信息提供者
        client.apiInfoProvider = info

        let storage = UserDefaultsStorage()

        // 初始化各个 API 模块
        audioStation = AudioStationApi(apiClient: client, storage: storage)
        fileStation = FileStationApi(apiClient: client)
        auth = AuthApi(apiClient: client, storage: storage)

        quickConnect = QuickConnectApi(deviceConnection: connection,
                                       apiClient: client,
                                       pingpong: pingpong,
                                       timeout: config.quickConnectTimeout,
                                       storage: storage)
        dsmInfo = DsmInfoApi(apiClient: client)
        encryption = EncryptionApi(apiClient: client)

        // 初始化流程类
        userLogin = SynologyUserLogin(deviceConnection: connection, apiInfoApi: info, apiClient: client, pingpong: pingpong)
        checkConnection = CheckDeviceConnection(deviceConnection: connection, apiInfoApi: info, pingpong: pingpong, apiClient: client)
        queryAllSongs = QueryAllSongs(apiClient: client)
    }
}
