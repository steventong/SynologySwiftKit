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

                let ping = await pingpong.pingpong(url: connectionUrl)
                if ping {
                    // 连接可用
                    DeviceConnection.shared.updateCurrentConnectionUrl(type: connectionType, url: connectionUrl)
                    // 更新API info
                    try await ApiInfoApi.shared.queryApiInfo(cacheEnabled: false)

                    // 成功回调
                    DispatchQueue.main.async {
                        onFinish(true, (connectionType, connectionUrl))
                    }
                    return
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
            guard fetchNewServerByQuickConnectId, let loginPreferences = DeviceConnection.shared.getLoginPreferences() else {
                return
            }

            // fetch server connection by qc
            do {
                if let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: loginPreferences.server, enableHttps: loginPreferences.isEnableHttps) {
                    // 新的连接地址信息
                    DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)
                    // 更新API info
                    try await ApiInfoApi.shared.queryApiInfo()

                    // 成功回调
                    DispatchQueue.main.async {
                        onFinish(true, connection)
                    }
                    return
                }
            } catch {
                print(error)
            }

            DispatchQueue.main.async {
                onFinish(false, nil)
            }
        }
    }
}
