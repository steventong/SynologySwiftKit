//
//  QuickConnectApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/24.
//

import Foundation

/// QuickConnect API，通过 Synology QuickConnect 服务查找设备连接地址
/// QuickConnect API for discovering device connection URLs via Synology QuickConnect service
public actor QuickConnectApi {
    private let apiClient: ApiClientProviding
    private let pingpong: PingPongProviding
    private let storage: KeyValueStorage
    private let timeout: TimeInterval

    public init(apiClient: ApiClientProviding,
                pingpong: PingPongProviding,
                timeout: TimeInterval = SynologyConfig.default.quickConnectTimeout,
                storage: KeyValueStorage = UserDefaultsStorage()) {
        self.apiClient = apiClient
        self.pingpong = pingpong
        self.timeout = timeout
        self.storage = storage
    }

    /// 通过 QuickConnect ID 获取设备连接地址（竞速模式，首个最优连接立即返回）
    /// Get device connection URL by QuickConnect ID (race mode, returns first best connection)
    /// - Throws: SynologyError.quickConnect(.serverInfoNotFound) or SynologyError.quickConnect(.connectionFailed)
    public func getDeviceConnection(quickConnectId: String, enableHttps: Bool) async throws -> (type: ConnectionType, url: String) {
        // 获取 serverInfo 信息
        // Fetch serverInfo
        let serverInfo = try await queryAvailableServerInfo(quickConnectId: quickConnectId, enableHttps: enableHttps)
        guard let serverInfo else {
            Logger.error("QuickConnectApi.getDeviceConnection query device serverInfo failed")
            throw SynologyError.network(message: "QuickConnect server info not available")
        }

        // 从站点返回中解析设备连接信息
        // Parse device connection info from server response
        let connections = parseConnectionUrls(serverInfo: serverInfo.serverInfo, enableHttps: enableHttps, isRequestTunnel: false)

        // 竞速查找可用连接：pingpong 测试 + requestTunnel 并发，首个最优结果立即返回
        // Race for available connection: pingpong test + requestTunnel concurrent, first best result returns immediately
        let connectionUrl = await raceForBestConnection(connections: connections, synologyServer: serverInfo.synologyServer, quickConnectId: quickConnectId, enableHttps: enableHttps)

        guard let connectionUrl else {
            throw SynologyError.network(message: "Failed to establish QuickConnect connection")
        }

        return (connectionUrl.type, connectionUrl.url)
    }
}

// MARK: - Server Info Discovery

private extension QuickConnectApi {
    /// 获取可用的 serverInfo（带站点重定向支持）
    /// Fetch available serverInfo (with site redirection support)
    func queryAvailableServerInfo(quickConnectId: String, enableHttps: Bool) async throws -> (synologyServer: String, serverInfo: ServerInfo)? {
        let cachedSynologyServer = fetchSynologyServerFromCache(quickConnectId: quickConnectId)

        let serverInfo = try await invokeSynologyServiceApi(synologyServer: cachedSynologyServer, quickConnectId: quickConnectId, enableHttps: enableHttps, command: .get_server_info)
        if serverInfo.errno == 0 {
            Logger.debug("quickConnectId: \(quickConnectId), find available serverInfo: \(serverInfo)")
            return (cachedSynologyServer, serverInfo)
        }

        // 需要处理 sites 信息，转发到其他站点
        // Handle sites redirection
        if let synologyServers = serverInfo.sites, !synologyServers.isEmpty {
            Logger.debug("quickConnectId: \(quickConnectId), find available serverInfo on sites: \(synologyServers), errno = \(serverInfo.errno), suberrno=\(serverInfo.suberrno ?? -999)")

            let multiServerInfos = try await raceMultiSiteServerInfo(synologyServers: synologyServers, quickConnectId: quickConnectId, enableHttps: enableHttps)
            if let multiServerInfos {
                // 新的地址保存到缓存，下次请求可以加速。
                saveSynologyServerToCache(quickConnectId: quickConnectId, synologyServer: multiServerInfos.synologyServer)
                return multiServerInfos
            }
        }

        Logger.info("get_server_info can not find serverInfo, serverInfo is empty. code = \(serverInfo.errno)")
        return nil
    }

    /// 多站点并发查询（竞速模式，首个成功立即返回并取消其他）
    /// Race multiple site queries, return first success and cancel the rest
    func raceMultiSiteServerInfo(synologyServers: [String], quickConnectId: String, enableHttps: Bool) async throws -> (synologyServer: String, serverInfo: ServerInfo)? {
        Logger.debug("raceMultiSiteServerInfo: querying \(synologyServers)")
        return await withTaskGroup(of: (synologyServer: String, serverInfo: ServerInfo)?.self) { group in
            for synologyServer in synologyServers {
                group.addTask {
                    do {
                        let serverInfo = try await self.invokeSynologyServiceApi(synologyServer: synologyServer, quickConnectId: quickConnectId, enableHttps: enableHttps, command: .get_server_info)
                        if serverInfo.errno == 0 {
                            Logger.debug("get_server_info result success from \(synologyServer)")
                            return (synologyServer, serverInfo)
                        }
                    } catch {
                        Logger.debug("invokeSynologyGetServerInfo error: \(error)")
                    }
                    Logger.debug("get_server_info failed, from \(synologyServer)")
                    return nil
                }
            }

            // 首个成功立即返回，取消其余任务
            // Return first success, cancel remaining tasks
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }

    /// 竞速查找最优连接：pingpong 和 requestTunnel 并发，首个可用连接立即返回
    /// Race pingpong and requestTunnel concurrently, return first available connection
    private func raceForBestConnection(connections: [ConnectionType: [String]], synologyServer: String, quickConnectId: String, enableHttps: Bool) async -> (type: ConnectionType, url: String)? {
        await withTaskGroup(of: (type: ConnectionType, url: String)?.self) { group in
            // 子任务 1：pingpong 测试所有已解析地址的可达性（竞速模式）
            // Task 1: Ping all parsed addresses for reachability (race mode)
            group.addTask {
                Logger.debug("QuickConnectApi.raceForBestConnection: starting pingpong task")
                return await self.pingpong.pingpongFirst(connections: connections)
            }

            // 子任务 2：requestTunnel 获取 relay 连接（仅当没有 relay 地址时）
            // Task 2: Request tunnel for relay connection (only if no relay address present)
            group.addTask {
                Logger.debug("QuickConnectApi.raceForBestConnection: starting requestTunnel task")
                return await self.requestForRelayConnection(connections: connections, synologyServer: synologyServer, quickConnectId: quickConnectId, enableHttps: enableHttps)
            }

            // 竞速收集结果，取优先级最高的
            // Race to collect results, pick the highest priority
            var best: (type: ConnectionType, url: String)?
            for await result in group {
                guard let result else { continue }

                if let current = best {
                    // 比较优先级
                    let resultPriority = ConnectionType.ordered.firstIndex(of: result.type) ?? Int.max
                    let currentPriority = ConnectionType.ordered.firstIndex(of: current.type) ?? Int.max
                    if resultPriority < currentPriority {
                        best = result
                    }
                } else {
                    best = result
                }

                // 如果已经找到非 relay 类型（高优先级），不需要等 requestTunnel
                // If a non-relay type (high priority) is found, no need to wait for requestTunnel
                if let best, best.type != .relay {
                    group.cancelAll()
                    Logger.debug("QuickConnectApi.raceForBestConnection: found high-priority connection \(best.type), cancelling remaining tasks")
                    return best
                }
            }

            if let best {
                Logger.debug("QuickConnectApi.raceForBestConnection: best connection: \(best)")
            } else {
                Logger.warn("QuickConnectApi.raceForBestConnection: no reachable connection found")
            }
            return best
        }
    }
}

private extension QuickConnectApi {
    /// 从缓存获取 synology server
    /// Fetch synology server URL from cache
    func fetchSynologyServerFromCache(quickConnectId: String) -> String {
        // 根据 quickconnectId 配置缓存的 url
        let key = UserDefaultsKeys.SYNOLOGY_SERVER_URL(quickConnectId).keyName
        if let synologyServerUrl = storage.string(forKey: key) {
            Logger.info("[SynologySwiftKit][QuickConnect]cached synology server: \(synologyServerUrl)")
            return synologyServerUrl
        }

        Logger.info("[SynologySwiftKit][QuickConnect]default synology server: \(SynologySwiftKitConstant.GLOBAL_SYNOLOGY_CONNECT_SERVER)")
        return SynologySwiftKitConstant.GLOBAL_SYNOLOGY_CONNECT_SERVER
    }

    /// 保存 synology server 到缓存
    /// Save synology server URL to cache
    func saveSynologyServerToCache(quickConnectId: String, synologyServer: String) {
        let key = UserDefaultsKeys.SYNOLOGY_SERVER_URL(quickConnectId).keyName
        storage.set(synologyServer, forKey: key)
        Logger.debug("persist user-defaults: \(key)=\(synologyServer)")
    }
}

// MARK: - Network Requests

private extension QuickConnectApi {
    /// 请求 relay 连接（仅当解析结果中没有 relay 地址时才发起 requestTunnel）
    /// Request relay connection (only sends requestTunnel when no relay address in parsed results)
    func requestForRelayConnection(connections: [ConnectionType: [String]], synologyServer: String, quickConnectId: String, enableHttps: Bool) async -> (type: ConnectionType, url: String)? {
        // 如果已有 relay 地址则不需要 requestTunnel
        // Skip if relay addresses already exist
        if connections.keys.contains(.relay) {
            return nil
        }

        Logger.debug("relay connection is not present, send request_tunnel request, synologyServer = \(synologyServer)")

        do {
            let serverInfo = try await invokeSynologyServiceApi(synologyServer: synologyServer, quickConnectId: quickConnectId, enableHttps: enableHttps, command: .request_tunnel)

            let tunnelConnections = parseConnectionUrls(serverInfo: serverInfo, enableHttps: enableHttps, isRequestTunnel: true)
            if let relay = tunnelConnections[.relay]?.first {
                Logger.debug("parse relay connection: \(relay)")
                return (.relay, relay)
            }
        } catch {
            Logger.debug("parse relay connection error: \(error)")
        }

        return nil
    }

    /// 发起 get_server_info / request_tunnel 请求
    /// Send get_server_info or request_tunnel request
    func invokeSynologyServiceApi(synologyServer: String, quickConnectId: String, enableHttps: Bool, command: QuickConnectServerCommand) async throws -> ServerInfo {
        let synologyServerUrl = "https://\(synologyServer)/Serv.php"

        guard let url = URL(string: synologyServerUrl) else {
            throw SynologyError.network(message: "Invalid QuickConnect URL")
        }

        let requestParams = SynoGetServerInfoRequest(id: enableHttps ? .dsm_https : .dsm, command: command, serverID: quickConnectId)
        let result: ServerInfo = try await apiClient.requestRaw(url: url,
                                                                httpMethod: .post,
                                                                headers: ["Content-Type": "application/json"],
                                                                body: try JSONEncoder().encode(requestParams),
                                                                timeout: timeout)
        return result
    }
}

// MARK: - Connection URL Parsing

private extension QuickConnectApi {
    /// 从 ServerInfo 解析所有连接 URL（数据驱动，消除重复代码）
    /// Parse all connection URLs from ServerInfo (data-driven, eliminates duplicate code)
    func parseConnectionUrls(serverInfo: ServerInfo, enableHttps: Bool, isRequestTunnel: Bool) -> [ConnectionType: [String]] {
        let scheme = enableHttps ? "https://" : "http://"
        let targetTypes: Set<ConnectionType> = isRequestTunnel ? [.relay] : [.lan, .wan, .lanv6, .wanv6, .ddns, .relay]

        let rules: [ConnectionParseRule] = [
            // LAN: 接口 IP + smartdns LAN
            // LAN: interface IPs + smartdns LAN
            ConnectionParseRule(type: .lan) { info, scheme in
                var urls: [String] = []
                info.server?.interface?.forEach { iface in
                    if let host = iface.ip, let port = info.service?.port {
                        urls.append("\(scheme)\(host):\(port)")
                    }
                }
                info.smartdns?.lan?.forEach { host in
                    if let port = info.service?.port {
                        urls.append("\(scheme)\(host):\(port)")
                    }
                }
                return urls
            },
            // WAN: 外部 IP
            // WAN: external IP
            ConnectionParseRule(type: .wan) { info, scheme in
                guard let host = info.server?.external?.ip, let port = info.service?.port else { return [] }
                return ["\(scheme)\(host):\(port)"]
            },
            // LAN IPv6: 接口 IPv6（addr_type == 0）
            // LAN IPv6: interface IPv6 (addr_type == 0)
            ConnectionParseRule(type: .lanv6) { info, scheme in
                var urls: [String] = []
                info.server?.interface?.forEach { iface in
                    iface.ipv6?.forEach { ipv6 in
                        if ipv6.addr_type == 0, let host = ipv6.address, let port = info.service?.port {
                            urls.append("\(scheme)\(host):\(port)")
                        }
                    }
                }
                return urls
            },
            // WAN IPv6: 接口 IPv6 + 外部 IPv6
            // WAN IPv6: interface IPv6 + external IPv6
            ConnectionParseRule(type: .wanv6) { info, scheme in
                var urls: [String] = []
                info.server?.interface?.forEach { iface in
                    iface.ipv6?.forEach { ipv6 in
                        if ipv6.addr_type == 0, let host = ipv6.address, let port = info.service?.ext_port {
                            urls.append("\(scheme)\(host):\(port)")
                        }
                    }
                }
                if let host = info.server?.external?.ipv6, let port = info.service?.port {
                    urls.append("\(scheme)\(host):\(port)")
                }
                if let host = info.server?.external?.ipv6, let port = info.service?.ext_port {
                    urls.append("\(scheme)\(host):\(port)")
                }
                return urls
            },
            // DDNS: 动态 DNS 域名
            // DDNS: dynamic DNS hostname
            ConnectionParseRule(type: .ddns) { info, scheme in
                var urls: [String] = []
                if let host = info.server?.ddns, let port = info.service?.port {
                    urls.append("\(scheme)\(host):\(port)")
                }
                if let host = info.server?.ddns, let port = info.service?.ext_port {
                    urls.append("\(scheme)\(host):\(port)")
                }
                return urls
            },
            // Relay: 中继连接
            // Relay: relay connection
            ConnectionParseRule(type: .relay) { info, scheme in
                guard let host = info.service?.relay_dn, let port = info.service?.relay_port else { return [] }
                return ["\(scheme)\(host):\(port)"]
            },
        ]

        var connections: [ConnectionType: [String]] = [:]
        for rule in rules where targetTypes.contains(rule.type) {
            let urls = rule.extractor(serverInfo, scheme)
            if !urls.isEmpty {
                connections[rule.type] = urls
            }
        }

        Logger.debug("parseConnectionUrls: require: \(targetTypes), result: \(connections)")
        return connections
    }

    /// 地址解析规则定义
    /// Address parsing rule definition
    struct ConnectionParseRule {
        let type: ConnectionType
        let extractor: (ServerInfo, String) -> [String]
    }
}
