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
    let pingpong = PingPong()
    let audioStationApi = AudioStationApi()

    public init() {
    }

    /**
     check device connection status
     */
    public func checkConnectionStatus(fetchNewServerByQuickConnectId: Bool = false, onFinish: @escaping (_ success: Bool, _ connection: (type: ConnectionType, url: String)?) -> Void) {
        Task {
            // ping current connection url
            if let connection = DeviceConnection.shared.getCurrentConnectionUrl() {
                let connectionUrl = connection.url
                let connectionType = connection.type

                Logger.info("CheckDeviceConnection, checking exist connection: \(connection)")

                let ping = await pingpong.pingpong(url: connectionUrl)
                if ping {
                    // 连接可用
                    // 更新API info
                    try await ApiInfoApi.shared.queryApiInfo(cacheEnabled: false)
                    // 查询 audio station 信息
                    let audioStationInfo = try await audioStationApi.queryAudioStationInfo()
                    Logger.info("CheckDeviceConnection, audioStationInfo: \(audioStationInfo)")

                    // 成功回调
                    DispatchQueue.main.async {
                        onFinish(true, (connectionType, connectionUrl))
                    }
                    return
                } else {
                    Logger.error("CheckDeviceConnection, checking exist connection, ping failed")
                }

                if connectionType == .custom_domain {
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
                return
            }

            // fetch server connection by qc
            do {
                Logger.info("CheckDeviceConnection, checking new connection: \(loginServer)")

                if let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: loginServer.server, enableHttps: loginServer.isEnableHttps) {
                    // 新的连接地址信息
                    DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)
                    // 更新API info
                    try await ApiInfoApi.shared.queryApiInfo()

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
