//
//  File.swift
//
//
//  Created by Steven on 2024/4/30.
//

import Foundation

public class CheckDeviceConnection {
    let quickConnect = QuickConnect()
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

            // 判断满足 quick connect id 条件
            let isQuickConnectId = await quickConnect.isQuickConnectId(server: loginPreferences.server)
            // fetch server connection by qc
            do {
                if let connection = try await quickConnect.getDeviceConnectionByQuickConnectId(quickConnectId: loginPreferences.server, enableHttps: loginPreferences.isEnableHttps) {
                    // 新的连接地址信息
                    DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)
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
