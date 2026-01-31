//
//  QuickConnectApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/24.
//

import Foundation

public actor QuickConnectApi {
    private let httpClient: HTTPClient
    private let deviceConnection: DeviceConnectionProviding
    let pingpong = PingPong()

    public init(deviceConnection: DeviceConnectionProviding) {
        self.httpClient = HTTPClient(timeout: 10)
        self.deviceConnection = deviceConnection
    }

    /// 通过 QuickConnect ID 获取设备连接地址
    public func getDeviceConnectionByQuickConnectId(
        quickConnectId: String, enableHttps: Bool, save: Bool? = false
    ) async throws -> (type: ConnectionType, url: String)? {
        // 获取 serverInfo 信息
        let serverInfo = try await queryAvaliableServerInfo(
            quickConnectId: quickConnectId, enableHttps: enableHttps)

        guard let serverInfo else {
            Logger.error(
                "QuickConnectApi.getDeviceConnectionByQuickConnectId query device serverInfo failed"
            )
            throw SynologyError.quickConnect(.serverInfoNotFound)
        }

        // 从站点返回中解析设备连接信息
        let connections = handleSynologyServiceApiResult(
            serverInfo: serverInfo.serverInfo, enableHttps: enableHttps, isRequestTunnel: false)

        // 测试获取连接信息，并请求 requestTunnel（如果没有 relay 类型的地址）
        let connectionUrl = await withTaskGroup(
            of: (connnectionType: ConnectionType, url: String)?.self,
            returning: (connnectionType: ConnectionType, url: String)?.self,
            body: { taskGroup in
                // 子任务：pingpong 获取到的地址, 测试可达性
                taskGroup.addTask {
                    Logger.debug(
                        "QuickConnectApi.getDeviceConnectionByQuickConnectId, pingpong task")
                    return await self.pingpongConnections(connections: connections)
                }

                // 子任务：requestTunnel
                taskGroup.addTask {
                    Logger.debug(
                        "QuickConnectApi.getDeviceConnectionByQuickConnectId, request_tunnel task")
                    return await self.requestForRelayConnection(
                        connections: connections, synologyServer: serverInfo.synologyServer,
                        quickConnectId: quickConnectId, enableHttps: enableHttps)
                }

                // 任务结果处理
                var finalConnections: [ConnectionType: String] = [:]
                for await result in taskGroup {
                    if let result {
                        finalConnections[result.connnectionType] = result.url
                    }
                }

                // 按顺序查找优先连接
                for connectionType in ConnectionType.ordered {
                    if let url = finalConnections[connectionType] {
                        return (connectionType, url)
                    }
                }

                return nil
            })

        if let connectionUrl {
            if save == true {
                await deviceConnection.updateCurrentConnectionUrl(
                    type: connectionUrl.connnectionType, url: connectionUrl.url)
            }

            return (connectionUrl.connnectionType, connectionUrl.url)
        }

        return nil
    }
}

extension QuickConnectApi {
    /// 判断是否是 QuickConnect ID
    func isQuickConnectId(server: String) -> Bool {
        if server.contains(".") {
            return false
        }
        return true
    }

    /// 获取 serverInfo
    private func queryAvaliableServerInfo(quickConnectId: String, enableHttps: Bool) async throws
        -> (synologyServer: String, serverInfo: ServerInfo)?
    {
        let synologyServer = fetchSynologyServerFromCache(quickConnectId: quickConnectId)

        let serverInfo = try await invokeSynologyServiceApi(
            synologyServer: synologyServer, quickConnectId: quickConnectId,
            enableHttps: enableHttps, command: .get_server_info)

        if serverInfo.errno == 0 {
            Logger.debug(
                "quickConnectId: \(quickConnectId), find avaliable serverInfo: \(serverInfo)")
            return (synologyServer, serverInfo)
        }

        // 需要处理 sites 信息，转发到其他站点
        if let synologyServers = serverInfo.sites, !synologyServers.isEmpty {
            Logger.debug(
                "quickConnectId: \(quickConnectId), find avaliable serverInfo on sites: \(synologyServers), errno = \(serverInfo.errno), suberrno=\(serverInfo.suberrno ?? -999)"
            )

            let multiServerInfos = try await invokeSynologyServiceApi(
                synologyServers: synologyServers, quickConnectId: quickConnectId,
                enableHttps: enableHttps)
            if let multiServerInfos {
                saveSynologyServerToCache(
                    quickConnectId: quickConnectId, synologyServer: multiServerInfos.synologyServer)
                return multiServerInfos
            }
        }

        Logger.info(
            "get_server_info can not find serverInfo, serverInfo is empty. code = \(serverInfo.errno)"
        )
        return nil
    }

    /// 从缓存获取 synology server
    private func fetchSynologyServerFromCache(quickConnectId: String) -> String {
        let key = UserDefaultsKeys.SYNOLOGY_SERVER_URL(quickConnectId).keyName

        if let synologyServerUrl = UserDefaults.standard.string(forKey: key) {
            Logger.info(
                "[SynologySwiftKit][QuickConnect]cached synology server: \(synologyServerUrl)")
            return synologyServerUrl
        }

        Logger.info(
            "[SynologySwiftKit][QuickConnect]default synology server: \(SynologySwiftKitConstant.GLOBAL_SYNOLOGY_CONNECT_SERVER)"
        )
        return SynologySwiftKitConstant.GLOBAL_SYNOLOGY_CONNECT_SERVER
    }

    /// 保存 synology server 到缓存
    private func saveSynologyServerToCache(quickConnectId: String, synologyServer: String) {
        let key = UserDefaultsKeys.SYNOLOGY_SERVER_URL(quickConnectId).keyName

        UserDefaults.standard.setValue(synologyServer, forKey: key)
        UserDefaults.standard.synchronize()

        Logger.debug("persist user-defaults: \(key)=\(synologyServer)")
    }

    /// 并发多个 get_server_info 请求
    private func invokeSynologyServiceApi(
        synologyServers: [String], quickConnectId: String, enableHttps: Bool
    ) async throws -> (synologyServer: String, serverInfo: ServerInfo)? {
        Logger.debug("send request: \(synologyServers)")
        return await withTaskGroup(
            of: (synologyServer: String, serverInfo: ServerInfo)?.self,
            returning: (synologyServer: String, serverInfo: ServerInfo)?.self,
            body: { taskGroup in

                for synologyServer in synologyServers {
                    taskGroup.addTask {
                        do {
                            let serverInfo = try await self.invokeSynologyServiceApi(
                                synologyServer: synologyServer, quickConnectId: quickConnectId,
                                enableHttps: enableHttps, command: .get_server_info)
                            if serverInfo.errno == 0 {
                                Logger.debug(
                                    "get_server_info result success from \(synologyServer)")
                                return (synologyServer, serverInfo)
                            }
                        } catch {
                            Logger.debug("invokeSynologyGetServerInfo error: \(error)")
                        }

                        Logger.debug("get_server_info failed, from \(synologyServer)")
                        return nil
                    }
                }

                for await task in taskGroup {
                    if let task {
                        return task
                    }
                }

                return nil
            })
    }

    /// 发起 get_server_info 请求
    private func invokeSynologyServiceApi(
        synologyServer: String, quickConnectId: String, enableHttps: Bool,
        command: QuickConnectServerCommand
    ) async throws -> ServerInfo {
        let requestParams = SynoGetServerInfoRequest(
            id: enableHttps ? .dsm_https : .dsm, command: command, serverID: quickConnectId)

        let synologyServerUrl = buildSynologyServerUrl(server: synologyServer)

        guard let url = URL(string: synologyServerUrl) else {
            throw SynologyError.quickConnect(.invalidURL)
        }

        return try await httpClient.postJSON(url: url, body: requestParams)
    }

    /// 解析地址
    private func handleSynologyServiceApiResult(
        serverInfo: ServerInfo, enableHttps: Bool, isRequestTunnel: Bool
    ) -> [ConnectionType: [String]] {
        var connections: [ConnectionType: [String]] = [:]
        let httpScheme = enableHttps ? "https://" : "http://"
        let targetType = parseConnectTypes(isRequestTunnel: isRequestTunnel)

        // 解析 lan 格式地址
        if targetType.contains(.lan) {
            var lanValues: [String] = []

            serverInfo.server?.interface?.forEach({ interface in
                if let host = interface.ip,
                    let port = serverInfo.service?.port
                {
                    lanValues.append("\(httpScheme)\(host):\(port)")
                }
            })

            serverInfo.smartdns?.lan?.forEach({ host in
                if let port = serverInfo.service?.port {
                    lanValues.append("\(httpScheme)\(host):\(port)")
                }
            })

            if !lanValues.isEmpty {
                connections[.lan] = lanValues
            }
        }

        // wan
        if targetType.contains(.wan) {
            var wanValues: [String] = []

            if let host = serverInfo.server?.external?.ip,
                let port = serverInfo.service?.port
            {
                wanValues.append("\(httpScheme)\(host):\(port)")
            }

            if !wanValues.isEmpty {
                connections[.wan] = wanValues
            }
        }

        // lan v6
        if targetType.contains(.lanv6) {
            var lanv6Values: [String] = []

            serverInfo.server?.interface?.forEach({ interface in
                interface.ipv6?.forEach({ ipv6 in
                    if ipv6.addr_type == 0,
                        let host = ipv6.address,
                        let port = serverInfo.service?.port
                    {
                        lanv6Values.append("\(httpScheme)\(host):\(port)")
                    }
                })
            })

            if !lanv6Values.isEmpty {
                connections[.lanv6] = lanv6Values
            }
        }

        // wan v6
        if targetType.contains(.wanv6) {
            var wanv6Values: [String] = []

            serverInfo.server?.interface?.forEach({ interface in
                interface.ipv6?.forEach({ ipv6 in
                    if ipv6.addr_type == 0,
                        let host = ipv6.address,
                        let port = serverInfo.service?.ext_port
                    {
                        wanv6Values.append("\(httpScheme)\(host):\(port)")
                    }
                })
            })

            if let host = serverInfo.server?.external?.ipv6,
                let port = serverInfo.service?.port
            {
                wanv6Values.append("\(httpScheme)\(host):\(port)")
            }

            if let host = serverInfo.server?.external?.ipv6,
                let port = serverInfo.service?.ext_port
            {
                wanv6Values.append("\(httpScheme)\(host):\(port)")
            }

            if !wanv6Values.isEmpty {
                connections[.wanv6] = wanv6Values
            }
        }

        // 解析 ddns 格式地址
        if targetType.contains(.ddns) {
            var ddnsValues: [String] = []

            if let host = serverInfo.server?.ddns,
                let port = serverInfo.service?.port
            {
                ddnsValues.append("\(httpScheme)\(host):\(port)")
            }

            if let host = serverInfo.server?.ddns,
                let port = serverInfo.service?.ext_port
            {
                ddnsValues.append("\(httpScheme)\(host):\(port)")
            }

            if !ddnsValues.isEmpty {
                connections[.ddns] = ddnsValues
            }
        }

        // 解析 relay 格式地址
        if targetType.contains(.relay) {
            var relayValues: [String] = []

            if let host = serverInfo.service?.relay_dn,
                let port = serverInfo.service?.relay_port
            {
                relayValues.append("\(httpScheme)\(host):\(port)")
            }

            if !relayValues.isEmpty {
                connections[.relay] = relayValues
            }
        }

        Logger.debug("parse connections, require: \(targetType), result: \(connections)")
        return connections
    }

    private func parseConnectTypes(isRequestTunnel: Bool) -> [ConnectionType] {
        if isRequestTunnel {
            return [.relay]
        }

        return [.lan, .wan, .lanv6, .wanv6, .ddns, .relay]
    }

    /// pingpong
    private func pingpongConnections(connections: [ConnectionType: [String]]) async -> (
        ConnectionType, String
    )? {
        let avaliablePingpong = await pingpong.pingpong(connections: connections)
        if !avaliablePingpong.isEmpty {
            for connectionType in ConnectionType.ordered {
                if let url = avaliablePingpong[connectionType] {
                    return (connectionType, url)
                }
            }
        }

        return nil
    }

    /// relay connection
    private func requestForRelayConnection(
        connections: [ConnectionType: [String]], synologyServer: String, quickConnectId: String,
        enableHttps: Bool
    ) async -> (ConnectionType, String)? {
        if connections.keys.contains(.relay) {
            return nil
        }

        Logger.debug(
            "relay connection is not present, send request_tunnel request, synologyServer = \(synologyServer)"
        )

        do {
            let serverInfo = try await invokeSynologyServiceApi(
                synologyServer: synologyServer, quickConnectId: quickConnectId,
                enableHttps: enableHttps, command: .request_tunnel)

            let connections = handleSynologyServiceApiResult(
                serverInfo: serverInfo, enableHttps: enableHttps, isRequestTunnel: true)
            if let relay = connections[.relay]?.first {
                Logger.debug("parse relay connection: \(relay)")
                return (ConnectionType.relay, relay)
            }
        } catch {
            Logger.debug("parse relay connection error: \(error)")
        }

        return nil
    }

    /// buildSynologyServerUrl
    private func buildSynologyServerUrl(server: String) -> String {
        return "https://\(server)/Serv.php"
    }
}
