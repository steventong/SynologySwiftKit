//
//  File.swift
//
//
//  Created by Steven on 2024/4/24.
//

import Alamofire
import Foundation

public actor QuickConnect {
    let session: Session

    init() {
        session = AlamofireClient.shared.session()
    }

    /**
     查询机器连接信息
     */
    func getDeviceConnection(quickConnectId: String) async throws -> (synologyServerUrl: String, connections: [ConnectionType: String], httpType: HttpType) {
        // 通过 quick connect Id 查询机器的地址连接信息
        let synologyServerUrl = fetchSynologyServerUrlFromCache(quickConnectId: quickConnectId)
        Logger.debug("quickConnectId: \(quickConnectId), initial synologyServerUrl: \(synologyServerUrl)")

        // 通过 get_server_info 查询 quickConnectId 机器信息和连接信息
        let synologyServerRequestUrl = buildServerUrlFromHost(host: synologyServerUrl)
        let serverInfos = try await invokeSynologyGetServerInfo(synologyServerUrl: synologyServerRequestUrl, quickConnectId: quickConnectId)

        // 结果
        var currentServerInfo: (synologyServerUrl: String, serverInfo: ServerInfo, httpType: HttpType)?

        // 在当前 synologyServer 获取到 serverInfo
        if let index = serverInfos.firstIndex(where: { $0.errno == 0 }) {
            currentServerInfo = (synologyServerUrl, serverInfos[index], index == 0 ? .HTTPS : .HTTP)
            Logger.debug("get_server_info result, from default synologyServerUrl, currentServerInfo: \(currentServerInfo!)")
        } else {
            // 解析机器信息和连接信息 serverInfos - 服务区域不正确（errno = 4，suberrno = 2），换区域重新请求 get_server_info
            let serverInfos: [ServerInfo] = serverInfos.filter({ $0.errno == 4 && $0.suberrno == 2 && $0.sites != nil })

            let newSynologyServerUrls: [String] = Array(Set(serverInfos.flatMap { $0.sites ?? [] }))
            if !newSynologyServerUrls.isEmpty {
                Logger.debug("quickConnectId: \(quickConnectId), find avaliable serverInfo on sites: \(newSynologyServerUrls)")

                // 在新的区域站点调用 get_server_info
                let serverInfo = try await invokeSynologyGetServerInfoOnMultiServers(synologyServerUrls: newSynologyServerUrls, quickConnectId: quickConnectId)
                if let serverInfo {
                    // 缓存地址下次使用
                    saveSynologyServerToCache(quickConnectId: quickConnectId, synologyServerUrl: serverInfo.synologyServerUrl)

                    currentServerInfo = (serverInfo.synologyServerUrl, serverInfo.serverInfo, serverInfo.httpType)
                    Logger.debug("get_server_info result, from new synologyServerUrl, currentServerInfo: \(currentServerInfo!)")
                }
            }
        }

        // 没有找到设备信息
        guard let currentServerInfo else {
            throw QuickConnectError.serverInfoNotFound
        }

        // 从站点返回中解析设备连接信息
        let connections = parseConnections(serverInfo: currentServerInfo.serverInfo, httpType: currentServerInfo.httpType
                                           , targetType: [.lan, .ddns, .relay])
        Logger.debug("parse connections: \(connections)")

        return (currentServerInfo.synologyServerUrl, connections, currentServerInfo.httpType)
    }

    /**
     查询机器连接信息。
     */
    func getDeviceRelayConnection(synologyServerUrl: String, quickConnectId: String, httpType: HttpType) async -> String? {
        do {
            let serverInfo = try await invokeSynologyRequestTunnel(synologyServerUrl: synologyServerUrl, quickConnectId: quickConnectId, httpType: httpType)

            // 从站点返回中解析设备连接信息
            let connections = parseConnections(serverInfo: serverInfo, httpType: httpType
                                               , targetType: [.relay])
            Logger.debug("parse relay connection: \(connections)")
            return connections[.relay] ?? nil
        } catch {
            print(error)
        }

        return nil
    }
}

extension QuickConnect {
    func fetchSynologyServerUrlFromCache(quickConnectId: String) -> String {
        let key = buildSynologyServerUrlUserDefaultsKey(quickConnectId: quickConnectId)

        if let synologyServerUrl = UserDefaults.standard.string(forKey: key) {
            Logger.debug("cached synologyServerUrl: \(synologyServerUrl)")
            return synologyServerUrl
        }

        return "global.quickconnect.to"
    }

    func saveSynologyServerToCache(quickConnectId: String, synologyServerUrl: String) {
        let key = buildSynologyServerUrlUserDefaultsKey(quickConnectId: quickConnectId)
        UserDefaults.standard.setValue(synologyServerUrl, forKey: key)
        Logger.debug("persist user-defaults: \(key)=\(synologyServerUrl)")
    }

    func buildSynologyServerUrlUserDefaultsKey(quickConnectId: String) -> String {
        return "SynologySwiftKit_SynologyServer_\(quickConnectId)"
    }

    func buildServerUrlFromHost(host: String) -> String {
        return "https://\(host)/Serv.php"
    }

    /**
     发起 get_server_info 请求
     */
    func invokeSynologyGetServerInfo(synologyServerUrl: String, quickConnectId: String) async throws -> [ServerInfo] {
        Logger.debug("send request: invokeSynologyGetServerInfo, \(synologyServerUrl)")

        // https 优先
        let parameter = [
            SynoGetServerInfoRequest(id: "dsm_portal_https", serverID: quickConnectId),
            SynoGetServerInfoRequest(id: "dsm_portal", serverID: quickConnectId),
        ]

        let getServerInfoResult = session.request(synologyServerUrl,
                                                  method: .post,
                                                  parameters: parameter,
                                                  encoder: JSONParameterEncoder.default)
            .serializingDecodable([ServerInfo].self)

        return try await getServerInfoResult.value
    }

    /**
     并发多个 get_server_info 请求
     */
    func invokeSynologyGetServerInfoOnMultiServers(synologyServerUrls: [String], quickConnectId: String) async throws -> (synologyServerUrl: String, serverInfo: ServerInfo, httpType: HttpType)? {
        Logger.debug("send request: invokeSynologyGetServerInfoOnMultiServers, \(synologyServerUrls)")
        return await withTaskGroup(of: (synologyServerUrl: String, serverInfo: ServerInfo, httpType: HttpType)?.self, returning: (synologyServerUrl: String, serverInfo: ServerInfo, httpType: HttpType)?.self, body: { taskGroup in

            // 子任务
            for synologyServerUrl in synologyServerUrls {
                taskGroup.addTask {
                    do {
                        let synologyServerRequestUrl = await self.buildServerUrlFromHost(host: synologyServerUrl)
                        let serverInfo = try await self.invokeSynologyGetServerInfo(synologyServerUrl: synologyServerRequestUrl, quickConnectId: quickConnectId)

                        if let index = serverInfo.firstIndex(where: { $0.errno == 0 }) {
                            let result = (synologyServerUrl, serverInfo[index], index == 0 ? HttpType.HTTPS : HttpType.HTTP)
                            Logger.debug("get_server_info result, from \(synologyServerUrl), currentServerInfo: \(result)")
                            return result
                        }
                    } catch {
                        print(error)
                    }

                    Logger.debug("get_server_info failed, from \(synologyServerUrl)")
                    return nil
                }
            }

            // 结果
            for await serverInfo in taskGroup {
                if let serverInfo {
                    Logger.debug("send request done: invokeSynologyGetServerInfoOnMultiServers")
                    return serverInfo
                }
            }

            Logger.debug("send request failed: invokeSynologyGetServerInfoOnMultiServers")
            return nil
        })
    }

    /**
     请求synology 服务端接口，
     */
    func invokeSynologyRequestTunnel(synologyServerUrl: String, quickConnectId: String, httpType: HttpType) async throws -> ServerInfo {
        Logger.debug("send request: invokeSynologyRequestTunnel \(synologyServerUrl)")

        let dsm_portal_id = httpType == .HTTPS ? "dsm_portal_https" : "dsm_portal"
        let getServerInfoResult = session.request(synologyServerUrl,
                                                  method: .post,
                                                  parameters: SynoRequestTunnelRequest(id: dsm_portal_id, serverID: quickConnectId),
                                                  encoder: JSONParameterEncoder.default)
            .serializingDecodable(ServerInfo.self)

        return try await getServerInfoResult.value
    }

    /**
     解析地址
     */
    func parseConnections(serverInfo: ServerInfo, httpType: HttpType, targetType: [ConnectionType]) -> [ConnectionType: String] {
        var connections: [ConnectionType: String] = [:]

        // 解析 lan 格式地址
        if targetType.contains(.lan) {
            if let lan = serverInfo.smartdns?.lan?.first,
               let port = serverInfo.service?.port {
                connections[.lan] = "\(httpType.httpScheme)\(lan):\(port)"
            }
        }

        // 解析 ddns 格式地址
        if targetType.contains(.ddns) {
            if let ddns = serverInfo.server?.ddns,
               let port = serverInfo.service?.port {
                connections[.ddns] = "\(httpType.httpScheme)\(ddns):\(port)"
            }
        }

        // 解析 relay 格式地址
        if targetType.contains(.relay) {
            if let relay_dn = serverInfo.service?.relay_dn,
               let relay_port = serverInfo.service?.relay_port {
                connections[.relay] = "\(httpType.httpScheme)\(relay_dn):\(relay_port)"
            }
        }

        Logger.debug("parse connections, require: \(targetType), result: \(connections)")
        return connections
    }
}
