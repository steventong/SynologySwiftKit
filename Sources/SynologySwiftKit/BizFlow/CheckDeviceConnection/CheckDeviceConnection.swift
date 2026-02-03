//
//  CheckDeviceConnection.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/30.
//

import Foundation

// MARK: - CheckDeviceConnection

/// 设备连接检查类（依赖注入）
/// Device connection checker (dependency injection)
public class CheckDeviceConnection {
    // MARK: - Dependencies

    private let deviceConnection: DeviceConnectionProviding
    private let apiInfoApi: ApiInfoProviding
    private let quickConnectApi: QuickConnectApi
    private let audioStationApi: AudioStationApi
    private let dsmInfoApi: DsmInfoApi
    private let pingpong: PingPongProviding

    // MARK: - Initialization

    /// 初始化连接检查器
    /// Initialize connection checker
    /// - Parameters:
    ///   - deviceConnection: 设备连接提供者
    ///   - apiInfoApi: API 信息提供者
    ///   - apiClient: API 客户端
    ///   - pingpong: PingPong 服务（可选，默认使用 PingPong()）
    public init(deviceConnection: DeviceConnectionProviding, apiInfoApi: ApiInfoProviding, pingpong: PingPongProviding, apiClient: ApiClientProviding) {
        self.deviceConnection = deviceConnection
        self.apiInfoApi = apiInfoApi
        self.pingpong = pingpong

        quickConnectApi = QuickConnectApi(deviceConnection: deviceConnection)
        audioStationApi = AudioStationApi(apiClient: apiClient)
        dsmInfoApi = DsmInfoApi(apiClient: apiClient)
    }

    // MARK: - Connection Status Check (AsyncStream)

    /// 检查设备连接状态（AsyncStream 版本）
    /// Check device connection status with AsyncStream for multiple progress updates
    /// - Parameter fetchNewServerByQuickConnectId: 是否通过 QuickConnect ID 获取新服务器地址
    /// - Returns: AsyncStream 返回连接检查进度
    public func checkConnectionStatus(fetchNewServerByQuickConnectId: Bool = false) -> AsyncStream<ConnectionCheckProgress> {
        AsyncStream { continuation in
            Task {
                await self.performConnectionCheck(fetchNewServerByQuickConnectId: fetchNewServerByQuickConnectId, continuation: continuation)
            }
        }
    }
}

// MARK: - Private Support

private extension CheckDeviceConnection {
    /// 执行连接检查的内部方法
    /// Internal method to perform connection check
    func performConnectionCheck(fetchNewServerByQuickConnectId: Bool, continuation: AsyncStream<ConnectionCheckProgress>.Continuation) async {
        // Step 1: 检查现有连接
        // Step 1: Check existing connection
        if let connection = await deviceConnection.getCurrentConnectionUrl() {
            Logger.info("CheckDeviceConnection#checkConnectionStatus, checking exist connection: \(connection)")
            continuation.yield(.checkingExistingConnection(url: connection.url))

            let pingOK = await pingpong.pingpong(url: connection.url)
            if pingOK {
                continuation.yield(.existingConnectionAvailable(type: connection.type, url: connection.url))

                // 验证 AudioStation
                // Verify AudioStation
                await verifyAudioStation(connectionType: connection.type, connectionUrl: connection.url, continuation: continuation)
                return
            } else if connection.type == .custom_domain {
                // 域名 ping 失败，结束
                // Custom domain ping failed, finish
                Logger.error("CheckDeviceConnection#checkConnectionStatus, custom domain ping failed")
                continuation.yield(.failed(reason: .customDomainPingFailed(url: connection.url)))
                continuation.finish()
                return
            }
            // ping 失败，继续尝试 QuickConnect
            // Ping failed, continue to try QuickConnect
        }

        // Step 2: 重新获取 QuickConnect
        // Step 2: Fetch new connection via QuickConnect
        guard fetchNewServerByQuickConnectId, let loginServer = await deviceConnection.getLoginServer() else {
            Logger.error("CheckDeviceConnection#checkConnectionStatus, no login server")
            continuation.yield(.sessionInvalid(reason: .noLoginServer))
            continuation.finish()
            return
        }

        continuation.yield(.fetchingQuickConnect(quickConnectId: loginServer.server))
        Logger.info("CheckDeviceConnection#checkConnectionStatus, checking new connection: \(loginServer)")

        do {
            if let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: loginServer.server, enableHttps: loginServer.isEnableHttps) {
                // 更新连接地址
                // Update connection URL
                await deviceConnection.updateCurrentConnectionUrl(type: connection.type, url: connection.url)
                continuation.yield(.quickConnectFetched(type: connection.type, url: connection.url))

                // 验证 AudioStation
                // Verify AudioStation
                await verifyAudioStation(connectionType: connection.type, connectionUrl: connection.url, continuation: continuation)
            } else {
                Logger.error("CheckDeviceConnection#checkConnectionStatus, checking new connection failed")
                continuation.yield(.failed(reason: .quickConnectFetchFailed))
                continuation.finish()
            }
        } catch SynologyError.api(.invalidSession) {
            Logger.error("CheckDeviceConnection#checkConnectionStatus, invalidSession")
            continuation.yield(.sessionInvalid(reason: .sessionInvalid))
            continuation.finish()
        } catch {
            Logger.error("CheckDeviceConnection#checkConnectionStatus error: \(error)")
            continuation.yield(.failed(reason: .quickConnectFetchFailed))
            continuation.finish()
        }
    }

    /// 验证 AudioStation 连接
    /// Verify AudioStation connection
    func verifyAudioStation(connectionType: ConnectionType, connectionUrl: String, continuation: AsyncStream<ConnectionCheckProgress>.Continuation) async {
        continuation.yield(.queryingApiInfo)

        do {
            // 更新 API 信息
            // Update API info
            _ = try await apiInfoApi.checkSynologyApiInfo(cacheEnabled: true)

            continuation.yield(.queryingAudioStation)

            // 查询 AudioStation 信息
            // Query AudioStation info
            let audioStationInfo = try await audioStationApi.info.query()
            Logger.info("CheckDeviceConnection#checkConnectionStatus, audioStationInfo: \(audioStationInfo)")

            continuation.yield(.success(type: connectionType, url: connectionUrl, audioStationInfo: audioStationInfo))
            continuation.finish()
        } catch SynologyError.api(.invalidSession) {
            Logger.error("CheckDeviceConnection#checkConnectionStatus, invalidSession during AudioStation query")
            continuation.yield(.sessionInvalid(reason: .sessionInvalid))
            continuation.finish()
        } catch {
            Logger.error("CheckDeviceConnection#checkConnectionStatus, AudioStation query failed: \(error)")
            continuation.yield(.failed(reason: .audioStationQueryFailed(error: error.localizedDescription)))
            continuation.finish()
        }
    }
}
