//
//  PingPong.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

class PingPong {
    private let httpClient: HTTPClient

    init() {
        httpClient = HTTPClient(timeout: 3.6)
    }

    /// 并发测试多个连接地址的可达性
    /// - Parameter connections: 连接类型到地址列表的映射
    /// - Returns: 可达的连接类型到地址的映射
    func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String] {
        return await withTaskGroup(of: (connnectionType: ConnectionType, url: String)?.self, returning: [ConnectionType: String].self, body: { taskGroup in
            // 子任务
            connections.forEach { connection in
                connection.value.forEach { item in
                    taskGroup.addTask {
                        if await self.pingpong(url: item) {
                            return (connection.key, item)
                        }
                        return nil
                    }
                }
            }

            // 结果
            var data: [ConnectionType: String] = [:]
            for await result in taskGroup {
                if let result, data[result.connnectionType] == nil {
                    // 同种类型只需要保留一个
                    data[result.connnectionType] = result.url
                }
            }

            Logger.debug("send request: pingpong result: \(data)")
            return data
        })
    }

    /// 测试单个 URL 的可达性
    /// - Parameter url: 要测试的 URL
    /// - Returns: 是否可达
    func pingpong(url: String) async -> Bool {
        let requestUrl = buildPingPongUrl(url: url)

        guard let url = URL(string: requestUrl) else {
            Logger.debug("send request: pingpong invalid url \(requestUrl)")
            return false
        }

        do {
            let result: PingPongResult = try await httpClient.get(url: url)
            return result.success
        } catch {
            return false
        }
    }
}

extension PingPong {
    /// 构建 PingPong URL
    private func buildPingPongUrl(url: String) -> String {
        return "\(url)/webman/pingpong.cgi?action=cors&quickconnect=true"
    }
}
