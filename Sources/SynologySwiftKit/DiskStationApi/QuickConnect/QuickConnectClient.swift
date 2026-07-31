//
//  QuickConnectClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/24.
//

import Foundation

/// QuickConnect API，通过 Synology QuickConnect 服务查找设备连接地址
/// QuickConnect API for discovering device connection URLs via Synology QuickConnect service
public final class QuickConnectClient {
    private let apiClient: RawRequestSending
    private let pingpong: PingPongProviding
    private let keyValueStorage: KeyValueStorage
    private let timeout: TimeInterval

    init(apiClient: RawRequestSending,
                pingpong: PingPongProviding,
                timeout: TimeInterval = SynologyConfig.default.quickConnectTimeout,
                keyValueStorage: KeyValueStorage = StorageService()) {
        self.apiClient = apiClient
        self.pingpong = pingpong
        self.timeout = timeout
        self.keyValueStorage = keyValueStorage
    }

    /// 通过 QuickConnect ID 获取设备连接地址（竞速模式，首个最优连接立即返回）
    /// Get device connection URL by QuickConnect ID (race mode, returns first best connection)
    /// - Throws: SynologyError.quickConnect(.serverInfoNotFound) or SynologyError.quickConnect(.connectionFailed)
    public func getDeviceConnection(quickConnectId: String, usesHTTPS: Bool) async throws -> SynologyConnection {
        // 获取 serverInfo 信息
        // Fetch serverInfo
        let serverInfo = try await queryAvailableServerInfo(quickConnectId: quickConnectId, usesHTTPS: usesHTTPS)
        guard let serverInfo else {
            Logger.error("QuickConnectClient.getDeviceConnection query device serverInfo failed")
            throw SynologyError.network(message: "QuickConnect server info not available")
        }

        // 从站点返回中解析设备连接信息
        // Parse device connection info from server response
        let connections = parseConnectionUrls(serverInfo: serverInfo.serverInfo, usesHTTPS: usesHTTPS, isRequestTunnel: false)

        // 竞速查找可用连接：pingpong 测试 + requestTunnel 并发，首个最优结果立即返回
        // Race for available connection: pingpong test + requestTunnel concurrent, first best result returns immediately
        let resolvedConnection = await raceForBestConnection(
            connections: connections.connectionMap,
            pingPongPaths: connections.pingPongPaths,
            synologyServer: serverInfo.synologyServer,
            quickConnectId: quickConnectId,
            usesHTTPS: usesHTTPS
        )

        guard let resolvedConnection else {
            throw SynologyError.network(message: "Failed to establish QuickConnect connection")
        }

        return SynologyConnection(type: resolvedConnection.type, url: resolvedConnection.url)
    }

    /// 获取当前 QuickConnect ID 对应的全部候选连接地址
    /// List all candidate connection endpoints for the current QuickConnect ID
    public func listDeviceConnections(quickConnectId: String, usesHTTPS: Bool) async throws -> [SynologyConnection] {
        let resolved = try await resolveConnectionCandidates(
            quickConnectId: quickConnectId,
            usesHTTPS: usesHTTPS
        )

        let currentConnectionMap = resolved.connectionMap
        let orderedTypes = ConnectionType.ordered

        return orderedTypes.flatMap { type in
            (currentConnectionMap[type] ?? []).map { url in
                SynologyConnection(type: type, url: url)
            }
        }
    }
}

// MARK: - Server Info Discovery

private extension QuickConnectClient {
    private func resolveConnectionCandidates(quickConnectId: String, usesHTTPS: Bool) async throws -> (synologyServer: String, connectionMap: [ConnectionType: [String]]) {
        let serverInfo = try await queryAvailableServerInfo(quickConnectId: quickConnectId, usesHTTPS: usesHTTPS)
        guard let serverInfo else {
            Logger.error("QuickConnectClient.resolveConnectionCandidates query device serverInfo failed")
            throw SynologyError.network(message: "QuickConnect server info not available")
        }

        var connections = parseConnectionUrls(
            serverInfo: serverInfo.serverInfo,
            usesHTTPS: usesHTTPS,
            isRequestTunnel: false
        )

        if !connections.connectionMap.keys.contains(.relay),
           let relay = await requestForRelayConnection(
               connections: connections.connectionMap,
               synologyServer: serverInfo.synologyServer,
               quickConnectId: quickConnectId,
               usesHTTPS: usesHTTPS
           )
        {
            connections.connectionMap[relay.type, default: []].append(relay.url)
        }

        return (serverInfo.synologyServer, deduplicated(connections.connectionMap))
    }

    /// 获取可用的 serverInfo（带站点重定向支持）
    /// Fetch available serverInfo (with site redirection support)
    private func queryAvailableServerInfo(quickConnectId: String, usesHTTPS: Bool) async throws -> (synologyServer: String, serverInfo: ServerInfo)? {
        let cachedSynologyServer = fetchSynologyServerFromCache(quickConnectId: quickConnectId)

        let serverInfo = try await invokeSynologyServiceApi(synologyServer: cachedSynologyServer, quickConnectId: quickConnectId, usesHTTPS: usesHTTPS, command: .get_server_info)
        if serverInfo.errno == 0 {
            Logger.debug("quickConnectId: \(quickConnectId), find available serverInfo: \(serverInfo)")
            return (cachedSynologyServer, serverInfo)
        }

        // 需要处理 sites 信息，转发到其他站点
        // Handle sites redirection
        if let synologyServers = serverInfo.sites, !synologyServers.isEmpty {
            Logger.debug("quickConnectId: \(quickConnectId), find available serverInfo on sites: \(synologyServers), errno = \(serverInfo.errno), suberrno=\(serverInfo.suberrno ?? -999)")

            let multiServerInfos = try await raceMultiSiteServerInfo(synologyServers: synologyServers, quickConnectId: quickConnectId, usesHTTPS: usesHTTPS)
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
    private func raceMultiSiteServerInfo(synologyServers: [String], quickConnectId: String, usesHTTPS: Bool) async throws -> (synologyServer: String, serverInfo: ServerInfo)? {
        Logger.debug("raceMultiSiteServerInfo: querying \(synologyServers)")
        return await withTaskGroup(of: (synologyServer: String, serverInfo: ServerInfo)?.self) { group in
            for synologyServer in synologyServers {
                group.addTask {
                    do {
                        let serverInfo = try await self.invokeSynologyServiceApi(synologyServer: synologyServer, quickConnectId: quickConnectId, usesHTTPS: usesHTTPS, command: .get_server_info)
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
    private func raceForBestConnection(connections: [ConnectionType: [String]], pingPongPaths: [String: String], synologyServer: String, quickConnectId: String, usesHTTPS: Bool) async -> (type: ConnectionType, url: String)? {
        await withTaskGroup(of: (type: ConnectionType, url: String)?.self) { group in
            // 子任务 1：pingpong 测试所有已解析地址的可达性（竞速模式）
            // Task 1: Ping all parsed addresses for reachability (race mode)
            group.addTask {
                Logger.debug("QuickConnectClient.raceForBestConnection: starting pingpong task")
                return await self.pingpong.pingpongFirst(connections: connections, pingPongPaths: pingPongPaths)
            }

            // 子任务 2：requestTunnel 获取 relay 连接（仅当没有 relay 地址时）
            // Task 2: Request tunnel for relay connection (only if no relay address present)
            group.addTask {
                Logger.debug("QuickConnectClient.raceForBestConnection: starting requestTunnel task")
                guard let relay = await self.requestForRelayConnection(
                    connections: connections,
                    synologyServer: synologyServer,
                    quickConnectId: quickConnectId,
                    usesHTTPS: usesHTTPS
                ) else {
                    return nil
                }

                guard await self.pingpong.pingpong(url: relay.url) else {
                    Logger.debug("QuickConnectClient.raceForBestConnection: relay endpoint unreachable: \(relay.url)")
                    return nil
                }
                return relay
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
                    Logger.debug("QuickConnectClient.raceForBestConnection: found high-priority connection \(best.type), cancelling remaining tasks")
                    return best
                }
            }

            if let best {
                Logger.debug("QuickConnectClient.raceForBestConnection: best connection: \(best)")
            } else {
                Logger.warn("QuickConnectClient.raceForBestConnection: no reachable connection found")
            }
            return best
        }
    }
}

private extension QuickConnectClient {
    private func deduplicated(_ connections: [ConnectionType: [String]]) -> [ConnectionType: [String]] {
        var result: [ConnectionType: [String]] = [:]
        for (type, urls) in connections {
            var seen = Set<String>()
            result[type] = urls.filter { seen.insert($0).inserted }
        }
        return result
    }

    /// 从缓存获取 synology server
    /// Fetch synology server URL from cache
    private func fetchSynologyServerFromCache(quickConnectId: String) -> String {
        // 根据 quickconnectId 配置缓存的 url
        let key = KeyValueStorageKeys.SYNOLOGY_SERVER_URL(quickConnectId).keyName
        if let synologyServerUrl = keyValueStorage.string(forKey: key) {
            Logger.info("[QuickConnect] cached synology server: \(synologyServerUrl)")
            return synologyServerUrl
        }

        Logger.info("[QuickConnect] default synology server: \(SynologySwiftKitConstant.GLOBAL_SYNOLOGY_CONNECT_SERVER)")
        return SynologySwiftKitConstant.GLOBAL_SYNOLOGY_CONNECT_SERVER
    }

    /// 保存 synology server 到缓存
    /// Save synology server URL to cache
    private func saveSynologyServerToCache(quickConnectId: String, synologyServer: String) {
        let key = KeyValueStorageKeys.SYNOLOGY_SERVER_URL(quickConnectId).keyName
        keyValueStorage.setString(synologyServer, forKey: key)
        Logger.debug("persist user-defaults: \(key)=\(synologyServer)")
    }
}

// MARK: - Network Requests

private extension QuickConnectClient {
    /// 请求 relay 连接（仅当解析结果中没有 relay 地址时才发起 requestTunnel）
    /// Request relay connection (only sends requestTunnel when no relay address in parsed results)
    private func requestForRelayConnection(connections: [ConnectionType: [String]], synologyServer: String, quickConnectId: String, usesHTTPS: Bool) async -> (type: ConnectionType, url: String)? {
        // 如果已有 relay 地址则不需要 requestTunnel
        // Skip if relay addresses already exist
        if connections.keys.contains(.relay) {
            return nil
        }

        Logger.debug("relay connection is not present, send request_tunnel request, synologyServer = \(synologyServer)")

        do {
            let serverInfo = try await invokeSynologyServiceApi(synologyServer: synologyServer, quickConnectId: quickConnectId, usesHTTPS: usesHTTPS, command: .request_tunnel)

            let tunnelConnections = parseConnectionUrls(serverInfo: serverInfo, usesHTTPS: usesHTTPS, isRequestTunnel: true)
            if let relay = tunnelConnections.connectionMap[.relay]?.first {
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
    private func invokeSynologyServiceApi(synologyServer: String, quickConnectId: String, usesHTTPS: Bool, command: QuickConnectServerCommand) async throws -> ServerInfo {
        let synologyServerUrl = "https://\(synologyServer)/Serv.php"

        guard let url = URL(string: synologyServerUrl) else {
            throw SynologyError.network(message: "Invalid QuickConnect URL")
        }

        let requestParams = SynoGetServerInfoRequest(
            id: usesHTTPS ? .audio_https : .audio_http,
            command: command,
            serverID: quickConnectId,
            location: command == .request_tunnel ? quickConnectLocation : nil,
            platform: command == .request_tunnel ? quickConnectPlatform : nil
        )
        let result: ServerInfo = try await apiClient.request(
            url: url,
            httpMethod: .post,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: try JSONEncoder().encode(requestParams),
            timeout: timeout
        )
        return result
    }

    var quickConnectLocation: String {
        Locale.current.regionCode?.lowercased() ?? ""
    }

    var quickConnectPlatform: String {
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #elseif os(watchOS)
        let platform = "watchOS"
        #elseif os(tvOS)
        let platform = "tvOS"
        #elseif os(visionOS)
        let platform = "visionOS"
        #else
        let platform = "Apple"
        #endif

        return "\(platform) \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }
}

// MARK: - Connection URL Parsing

private extension QuickConnectClient {
    /// 从 ServerInfo 解析所有连接 URL（数据驱动，消除重复代码）
    /// Parse all connection URLs from ServerInfo (data-driven, eliminates duplicate code)
    private func parseConnectionUrls(serverInfo: ServerInfo, usesHTTPS: Bool, isRequestTunnel: Bool) -> (connectionMap: [ConnectionType: [String]], pingPongPaths: [String: String]) {
        let scheme = usesHTTPS ? "https" : "http"
        let targetTypes: Set<ConnectionType> = isRequestTunnel ? [.relay] : [.lan, .wan, .lanv6, .wanv6, .ddns, .relay]
        let redirectPrefix = normalizedPathComponent(serverInfo.server?.redirect_prefix)
        let pingPongPath = resolvedPingPongPath(serverInfo: serverInfo, redirectPrefix: redirectPrefix)

        let rules: [ConnectionParseRule] = [
            // LAN: 接口 IP + smartdns LAN
            // LAN: interface IPs + smartdns LAN
            ConnectionParseRule(type: .lan) { info, scheme in
                var urls: [String?] = []
                info.server?.interface?.forEach { iface in
                    urls.append(self.makeURL(scheme: scheme, host: iface.ip, port: info.service?.port, basePath: redirectPrefix))
                }
                info.smartdns?.lan?.forEach { host in
                    urls.append(self.makeURL(scheme: scheme, host: host, port: info.service?.port, basePath: redirectPrefix))
                }
                return urls.compactMap { $0 }
            },
            // WAN: 外部直连，优先使用 NAT 映射端口，再回退到设备端口
            // WAN: external direct access, prefer NAT-mapped port then fall back to device port
            ConnectionParseRule(type: .wan) { info, scheme in
                let portCandidates = self.prioritizedPorts(info.service?.ext_port, info.service?.port)
                var urls: [String?] = []

                for port in portCandidates {
                    urls.append(self.makeURL(scheme: scheme, host: info.server?.external?.ip, port: port, basePath: redirectPrefix))
                }
                for port in portCandidates {
                    urls.append(self.makeURL(scheme: scheme, host: info.smartdns?.external, port: port, basePath: redirectPrefix))
                }
                if usesHTTPS {
                    urls.append(self.makeURL(scheme: scheme, host: info.service?.https_ip, port: info.service?.https_port, basePath: redirectPrefix))
                }

                return urls.compactMap { $0 }
            },
            // LAN IPv6: 全局可路由 IPv6 + SmartDNS LAN IPv6
            // LAN IPv6: globally routable IPv6 + SmartDNS LAN IPv6
            ConnectionParseRule(type: .lanv6) { info, scheme in
                var urls: [String?] = []
                info.server?.interface?.forEach { iface in
                    iface.ipv6?.forEach { ipv6 in
                        if self.isGloballyReachableIPv6(ipv6) {
                            urls.append(self.makeURL(scheme: scheme, host: ipv6.address, port: info.service?.port, basePath: redirectPrefix))
                        }
                    }
                }
                info.smartdns?.lanv6?.forEach { host in
                    urls.append(self.makeURL(scheme: scheme, host: host, port: info.service?.port, basePath: redirectPrefix))
                }
                return urls.compactMap { $0 }
            },
            // WAN IPv6: 外部 IPv6 / SmartDNS IPv6，优先映射端口
            // WAN IPv6: external IPv6 / SmartDNS IPv6, prefer mapped port
            ConnectionParseRule(type: .wanv6) { info, scheme in
                let portCandidates = self.prioritizedPorts(info.service?.ext_port, info.service?.port)
                var urls: [String?] = []

                for port in portCandidates {
                    urls.append(self.makeURL(scheme: scheme, host: info.server?.external?.ipv6, port: port, basePath: redirectPrefix))
                }
                for port in portCandidates {
                    urls.append(self.makeURL(scheme: scheme, host: info.smartdns?.externalv6, port: port, basePath: redirectPrefix))
                }

                return urls.compactMap { $0 }
            },
            // DDNS / SmartDNS Host: 直连域名，优先设备端口，再回退映射端口
            // DDNS / SmartDNS Host: direct hostnames, prefer device port then mapped port
            ConnectionParseRule(type: .ddns) { info, scheme in
                let portCandidates = self.prioritizedPorts(info.service?.port, info.service?.ext_port)
                var urls: [String?] = []
                for port in portCandidates {
                    urls.append(self.makeURL(scheme: scheme, host: info.server?.ddns, port: port, basePath: redirectPrefix))
                }
                for port in portCandidates {
                    urls.append(self.makeURL(scheme: scheme, host: info.smartdns?.host, port: port, basePath: redirectPrefix))
                }
                return urls.compactMap { $0 }
            },
            // Relay: 中继域名，优先双栈，再回退到 IPv4 / IPv6 relay
            // Relay: relay endpoints, prefer dual-stack then fall back to IPv4 / IPv6 relay
            ConnectionParseRule(type: .relay) { info, scheme in
                guard let port = info.service?.relay_port else { return [] }
                return [
                    self.makeURL(scheme: scheme, host: info.service?.relay_dualstack, port: port, basePath: redirectPrefix),
                    self.makeURL(scheme: scheme, host: info.service?.relay_dn, port: port, basePath: redirectPrefix),
                    self.makeURL(scheme: scheme, host: info.service?.relay_ipv6, port: port, basePath: redirectPrefix),
                ].compactMap { $0 }
            },
        ]

        var connections: [ConnectionType: [String]] = [:]
        var pingPongPaths: [String: String] = [:]
        for rule in rules where targetTypes.contains(rule.type) {
            let urls = rule.extractor(serverInfo, scheme)
            if !urls.isEmpty {
                connections[rule.type] = urls
                if let pingPongPath {
                    for url in urls {
                        pingPongPaths[url] = pingPongPath
                    }
                }
            }
        }

        Logger.debug("parseConnectionUrls: require: \(targetTypes), result: \(connections)")
        return (connections, pingPongPaths)
    }

    /// 地址解析规则定义
    /// Address parsing rule definition
    struct ConnectionParseRule {
        let type: ConnectionType
        let extractor: (ServerInfo, String) -> [String]
    }

    func prioritizedPorts(_ candidates: Int?...) -> [Int] {
        var seen = Set<Int>()
        return candidates.compactMap { $0 }.filter { seen.insert($0).inserted }
    }

    func makeURL(scheme: String, host: String?, port: Int?, basePath: String?) -> String? {
        guard let host = normalizedHost(host), let port else {
            return nil
        }
        let formattedHost = host.contains(":") ? "[\(host)]" : host
        let suffix = basePath.map { "/\($0)" } ?? ""
        return "\(scheme)://\(formattedHost):\(port)\(suffix)"
    }

    func normalizedHost(_ host: String?) -> String? {
        guard let host = host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty,
              host.uppercased() != "NULL"
        else {
            return nil
        }

        if host.hasPrefix("[") && host.hasSuffix("]") {
            return String(host.dropFirst().dropLast())
        }

        return host
    }

    func isGloballyReachableIPv6(_ ipv6: ServerInfo.ExternalInterfaceIpV6) -> Bool {
        if ipv6.scope?.lowercased() == "global" {
            return true
        }

        guard let address = ipv6.address?.lowercased() else {
            return false
        }

        return !address.hasPrefix("fe80:")
            && !address.hasPrefix("fc")
            && !address.hasPrefix("fd")
    }

    func normalizedPathComponent(_ value: String?) -> String? {
        guard let value = normalizedHost(value) else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? nil : trimmed
    }

    func resolvedPingPongPath(serverInfo: ServerInfo, redirectPrefix: String?) -> String? {
        let defaultPath = "webman/pingpong.cgi?action=cors&quickconnect=true"
        let explicitPath = normalizedHost(serverInfo.server?.pingpong_path)
        let trimmedExplicitPath = explicitPath?.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let target = trimmedExplicitPath?.isEmpty == false ? trimmedExplicitPath! : defaultPath
        let combined = [redirectPrefix, target]
            .compactMap { $0?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        return combined.isEmpty ? nil : "/\(combined)"
    }
}
