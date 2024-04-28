//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public class DeviceConnection {
    /**
     获取设备地址
     */
    func getDeviceConnectionByQuickConnectId(quickConnectId: String) async throws -> (type: ConnectionType, url: String)? {
        // 非 quickConnectID 直接返回
        guard isQuickConnectId(quickConnectId: quickConnectId) else {
            return (ConnectionType.custom_domain, quickConnectId)
        }

        // get server info by quick connect id
        let quickConnect = QuickConnect()
        let connection = try await quickConnect.getDeviceConnection(quickConnectId: quickConnectId)

        // pingpong
        let pingpong = PingPong()

        // 测试获取连接信息
        let connectionUrl = await withTaskGroup(of: (connnectionType: ConnectionType, url: String)?.self, returning: (connnectionType: ConnectionType, url: String)?.self, body: { taskGroup in
            // 子任务：pingpong 获取到的地址, 测试可达性
            taskGroup.addTask {
                Logger.debug("getDeviceConnectionByQuickConnectionId, add task1, pingpong task")
                let avaliablePingpong = await pingpong.pingpong(urls: connection.connections)
                if !avaliablePingpong.isEmpty {
                    // 优先返回的顺序
                    for connectionType in ConnectionType.ordered {
                        if let url = avaliablePingpong[connectionType] {
                            return (connectionType, url)
                        }
                    }
                }

                return nil
            }

            // 子任务：requestTunnel
            taskGroup.addTask {
                Logger.debug("getDeviceConnectionByQuickConnectionId, add task2, request relay connection task")
                // 如果不包含 relay，发出 requestTunnel, synology relay server
                if !connection.connections.keys.contains(.relay) {
                    Logger.debug("relay connection is not present, send request_tunnel request, synologyServerUrl = \(connection.synologyServerUrl)")
                    let synologyServerRequestUrl = await quickConnect.buildServerUrlFromHost(host: connection.synologyServerUrl)
                    if let relayUrl = await quickConnect.getDeviceRelayConnection(synologyServerUrl: synologyServerRequestUrl, quickConnectId: quickConnectId, httpType: connection.httpType) {
                        Logger.debug("send request_tunnel request, relayUrl: \(relayUrl)")
                        return (ConnectionType.relay, relayUrl)
                    }
                }

                return nil
            }

            // 任务结果处理
            var finalConnections: [ConnectionType: String] = [:]
            for await result in taskGroup {
                if let result {
                    finalConnections[result.connnectionType] = result.url
                }
            }
            for connectionType in ConnectionType.ordered {
                if let url = finalConnections[connectionType] {
                    return (connectionType, url)
                }
            }

            return nil
        })

        // 保存可用地址
        saveCurrentConnectionUrl(type: connectionUrl?.connnectionType, url: connectionUrl?.url)

        if let connectionUrl {
            return (connectionUrl.connnectionType, connectionUrl.url)
        }

        return nil
    }
}

extension DeviceConnection {
    /**
     判断是否是 quickConnect ID
     */
    func isQuickConnectId(quickConnectId: String) -> Bool {
        if quickConnectId.contains(".") {
            return false
        }

        return true
    }

    /**
     当前URL
     */
    func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)? {
        if let url = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName) {
            let type = UserDefaults.standard.integer(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            if let typeEnum = ConnectionType(rawValue: type) {
                Logger.info("getCurrentConnectionUrl, type = \(typeEnum), url = \(url)")
                return (typeEnum, url)
            }
        }

        Logger.info("getCurrentConnectionUrl, url = nil")
        return nil
    }

    /**
     saveCurrentConnectionUrl
     */
    private func saveCurrentConnectionUrl(type: ConnectionType?, url: String?) {
        if let type, let url {
            UserDefaults.standard.setValue(type.rawValue, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            UserDefaults.standard.setValue(url, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)

            Logger.info("saveCurrentConnectionUrl, save type = \(type), url = \(url)")
        } else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)

            Logger.info("saveCurrentConnectionUrl, removeObject type, url")
        }
    }

    /**
     pingpongCurrentConnection
     */
    private func pingpongCurrentConnectionUrl() async -> Bool {
        if let connection = getCurrentConnectionUrl() {
            let pingpong = PingPong()
            return await pingpong.pingpong(url: connection.url)
        }

        return false
    }
}
