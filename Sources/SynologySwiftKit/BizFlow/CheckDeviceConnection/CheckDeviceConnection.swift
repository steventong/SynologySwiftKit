//
//  File.swift
//
//
//  Created by Steven on 2024/4/30.
//

import Foundation

public class CheckDeviceConnection {
    let quickConnectApi = QuickConnectApi()
    let deviceConnection = DeviceConnection()
    let audioStationApi = AudioStationApi()
    let pingpong = PingPong()

    public init() {
    }

    /**
     check device connection status
     */
    public func checkConnectionStatus(fetchNewServerByQuickConnectId: Bool = false,
                                      onFinish: @escaping (_ success: Bool, _ connection: (type: ConnectionType, url: String)?) -> Void,
                                      onLoginRequired: @escaping () -> Void) {
        Task {
            // ping current connection url
            if let connection = DeviceConnection.shared.getCurrentConnectionUrl() {
                Logger.info("CheckDeviceConnection, checking exist connection: \(connection)")

                let pingOK = await pingpong.pingpong(url: connection.url)
                if pingOK {
                    do {
                        // 连接可用, 更新API info
                        try await ApiInfoApi.shared.checkSynologyApiInfo(cacheEnabled: true)

                        // 查询 audio station 信息
                        let audioStationInfo = try await audioStationApi.queryAudioStationInfo()
                        Logger.info("CheckDeviceConnection, audioStationInfo: \(audioStationInfo)")
                    } catch {
                        DispatchQueue.main.async {
                            onLoginRequired()
                        }
                        return
                    }

                    // 成功回调
                    DispatchQueue.main.async {
                        onFinish(true, connection)
                    }
                    return
                }

                Logger.error("CheckDeviceConnection, checking exist connection, ping failed: \(connection)")

                if connection.type == .custom_domain {
                    // 域名ping一次失败，结束
                    DispatchQueue.main.async {
                        onFinish(false, nil)
                    }
                    return
                }
            }

            // 重新获取 quick connect
            guard fetchNewServerByQuickConnectId,
                  let loginServer = DeviceConnection.shared.getLoginServer() else {
                Logger.error("CheckDeviceConnection, quickconnectId but login server not exist")
                DispatchQueue.main.async {
                    onLoginRequired()
                }
                return
            }

            // fetch server connection by qc
            do {
                Logger.info("CheckDeviceConnection, checking new connection: \(loginServer)")

                if let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: loginServer.server, enableHttps: loginServer.isEnableHttps) {
                    // 新的连接地址信息
                    DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)

                    // 连接可用, 更新API info
                    try await ApiInfoApi.shared.checkSynologyApiInfo(cacheEnabled: true)

                    // 查询 audio station 信息
                    let audioStationInfo = try await audioStationApi.queryAudioStationInfo()
                    Logger.info("CheckDeviceConnection, audioStationInfo: \(audioStationInfo)")

                    // 成功回调
                    DispatchQueue.main.async {
                        onFinish(true, connection)
                    }
                    return
                } else {
                    Logger.error("CheckDeviceConnection, checking new connection failed")
                }
            } catch {
                Logger.error("checkConnectionStatus error: \(error)")
            }

            DispatchQueue.main.async {
                onFinish(false, nil)
            }
        }
    }
}
