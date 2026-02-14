//
//  PingPong.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

/// PingPong 服务实现
/// PingPong service implementation
public final class PingPong: PingPongProviding {
    private let apiClient: ApiClientProviding
    private let timeout: TimeInterval

    public init(apiClient: ApiClientProviding, timeout: TimeInterval = SynologyConfig.default.pingpongTimeout) {
        self.apiClient = apiClient
        self.timeout = timeout
    }

    /// 并发测试多个连接地址的可达性，首个最高优先级类型可达即提前返回
    /// Test reachability of multiple connection URLs concurrently.
    /// Returns early when the highest possible priority type becomes reachable.
    public func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String] {
        let bestPossibleType = ConnectionType.ordered.first { connections.keys.contains($0) }

        return await withTaskGroup(of: (type: ConnectionType, url: String)?.self) { group in
            for (type, urls) in connections {
                for url in urls {
                    group.addTask {
                        await self.pingpong(url: url) ? (type, url) : nil
                    }
                }
            }

            var results: [ConnectionType: String] = [:]
            for await result in group {
                guard let result else { continue }
                // 同种类型只保留第一个可达的
                // Keep only the first reachable URL for each type
                if results[result.type] == nil {
                    results[result.type] = result.url
                }
                // 最高优先级类型已可达，提前返回
                // Best possible type is reachable, return early
                if let best = bestPossibleType, results[best] != nil {
                    group.cancelAll()
                    Logger.debug("pingpong: best type \(best) is reachable, returning early. results: \(results)")
                    return results
                }
            }

            Logger.debug("pingpong: all tasks completed. results: \(results)")
            return results
        }
    }

    /// 按连接类型优先级竞速，返回最优可达连接（首个最高优先级可达即返回）
    /// Race all URLs by connection type priority, return the best reachable connection.
    /// Cancels remaining tasks once the highest possible priority type is found.
    public func pingpongFirst(connections: [ConnectionType: [String]]) async -> (type: ConnectionType, url: String)? {
        let bestPossibleType = ConnectionType.ordered.first { connections.keys.contains($0) }

        return await withTaskGroup(of: (type: ConnectionType, url: String)?.self) { group in
            for (type, urls) in connections {
                for url in urls {
                    group.addTask {
                        await self.pingpong(url: url) ? (type, url) : nil
                    }
                }
            }

            var best: (type: ConnectionType, url: String)?
            for await result in group {
                guard let result else { continue }

                // 比较优先级，保留更优的
                // Compare priority, keep the better one
                if let current = best {
                    let resultIndex = ConnectionType.ordered.firstIndex(of: result.type) ?? Int.max
                    let currentIndex = ConnectionType.ordered.firstIndex(of: current.type) ?? Int.max
                    if resultIndex < currentIndex {
                        best = result
                    }
                } else {
                    best = result
                }

                // 已找到最高优先级，立即返回
                // Found the best possible type, return immediately
                if best?.type == bestPossibleType {
                    group.cancelAll()
                    Logger.debug("pingpongFirst: best type \(best!.type) found, returning early: \(best!.url)")
                    return best
                }
            }

            if let best {
                Logger.debug("pingpongFirst: all tasks completed, best: \(best)")
            } else {
                Logger.debug("pingpongFirst: all tasks completed, no reachable connection found")
            }
            return best
        }
    }

    /// 测试单个 URL 的可达性
    /// Test reachability of a single URL
    /// - Parameter url: 要测试的 URL / URL to test
    /// - Returns: 是否可达 / Whether the URL is reachable
    public func pingpong(url: String) async -> Bool {
        let requestUrl = buildPingPongUrl(url: url)

        guard let url = URL(string: requestUrl) else {
            Logger.debug("send request: pingpong invalid url \(requestUrl)")
            return false
        }

        do {
            let result: PingPongResult = try await apiClient.requestRaw(url: url,
                                                                        httpMethod: .get,
                                                                        headers: nil,
                                                                        body: nil,
                                                                        timeout: timeout)
            return result.success
        } catch {
            return false
        }
    }
}

extension PingPong {
    /// 构建 PingPong URL
    /// Build PingPong URL
    private func buildPingPongUrl(url: String) -> String {
        return "\(url)/webman/pingpong.cgi?action=cors&quickconnect=true"
    }
}
