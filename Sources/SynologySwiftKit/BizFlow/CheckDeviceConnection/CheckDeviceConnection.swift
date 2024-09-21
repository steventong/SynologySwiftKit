//
//  File.swift
//
//
//  Created by Steven on 2024/4/30.
//

import Foundation

public class CheckDeviceConnection {
    public static let shared = CheckDeviceConnection()

    let quickConnectApi = QuickConnectApi()
    let deviceConnection = DeviceConnection()
    let audioStationApi = AudioStationApi()
    let dsmInfoApi = DsmInfoApi()
    let pingpong = PingPong()

    public init() {
    }

    /**
     check device connection status
     */
    @MainActor
    public func checkConnectionStatus(fetchNewServerByQuickConnectId: Bool = false,
                                      onSuccess: @escaping (_ type: ConnectionType, _ url: String) -> Void,
                                      onFailed: @escaping () -> Void,
                                      onLoginRequired: @escaping () -> Void) {
        Task {
            // ping current connection url
            if let connection = DeviceConnection.shared.getCurrentConnectionUrl() {
                Logger.info("CheckDeviceConnection#checkConnectionStatus, checking exist connection: \(connection)")

                // connection is avaliable, try to ping it.
                let pingOK = await pingpong.pingpong(url: connection.url)
                if pingOK {
                    // 成功回调
                    return onSuccess(connection.type, connection.url)
                } else if connection.type == .custom_domain {
                    // 域名ping一次失败，结束
                    return onFailed()
                }

                // ping失败重新获取地址。
            }

            // 重新获取 quick connect
            guard fetchNewServerByQuickConnectId, let loginServer = DeviceConnection.shared.getLoginServer() else {
                Logger.error("CheckDeviceConnection#checkConnectionStatus, quickconnectId but login server not exist")
                return onLoginRequired()
            }

            // fetch server connection by qc
            do {
                Logger.info("CheckDeviceConnection#checkConnectionStatus, checking new connection: \(loginServer)")

                if let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: loginServer.server, enableHttps: loginServer.isEnableHttps) {
                    // 新的连接地址信息
                    DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)

                    self.queryAudioStationInfo(success: { _ in
                        // 成功回调
                        return onSuccess(connection.type, connection.url)
                    }, failed: {
                        return onFailed()
                    }, sessionInvalid: {
                        return onLoginRequired()
                    })
                } else {
                    Logger.error("CheckDeviceConnection#checkConnectionStatus, checking new connection failed")
                    return onFailed()
                }
            } catch DiskStationApiError.invalidSession {
                Logger.error("CheckDeviceConnection#checkConnectionStatus, invalidSession")
                return onLoginRequired()
            } catch {
                Logger.error("CheckDeviceConnection#checkConnectionStatus error: \(error)")
                return onFailed()
            }
        }
    }

    /**
     query dsmInfo
     */
    @MainActor
    public func queryDsmInfoApi(success: @escaping (DsmInfo) -> Void, failed: @escaping () -> Void, sessionInvalid: @escaping () -> Void) {
        Task {
            do {
                // 登录状态成功后，设备信息
                if let synoDeviceDsmInfo = try await self.dsmInfoApi.queryDmsInfo() {
                    Logger.info("CheckDeviceConnection#queryDsmInfoApi, fetch dsm info: \(synoDeviceDsmInfo)")

                    return success(synoDeviceDsmInfo)
                } else {
                    Logger.error("CheckDeviceConnection#queryDsmInfoApi, fetch dsm info failed")
                    return failed()
                }
            } catch DiskStationApiError.invalidSession {
                Logger.error("CheckDeviceConnection#queryDsmInfoApi, fetch dsm info error, invalidSession")
                return sessionInvalid()
            } catch {
                Logger.error("CheckDeviceConnection#queryDsmInfoApi, fetch dsm info error, error: \(error)")
                return failed()
            }
        }
    }

    @MainActor
    public func queryAudioStationInfo(success: @escaping (AudioStationInfo) -> Void, failed: @escaping () -> Void, sessionInvalid: @escaping () -> Void) {
        Task {
            do {
                // 连接可用, 更新API info.
                _ = try await ApiInfoApi.shared.checkSynologyApiInfo(cacheEnabled: true)

                // 查询 audio station 信息
                let audioStationInfo = try await audioStationApi.queryAudioStationInfo()
                Logger.info("CheckDeviceConnection#queryApiInfo, audioStationInfo: \(audioStationInfo)")

                // 成功回调
                return success(audioStationInfo)
            } catch DiskStationApiError.invalidSession {
                Logger.error("CheckDeviceConnection#queryApiInfo, fetch api info error, invalidSession")
                return sessionInvalid()
            } catch {
                Logger.error("CheckDeviceConnection#queryApiInfo, failed: \(error)")
                return failed()
            }
        }
    }
}
