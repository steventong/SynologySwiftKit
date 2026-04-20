//
//  PingPongProviding.swift
//  SynologySwiftKit
//
//  Created by Steven on 06/02/2026.
//

import Foundation

/// PingPong 服务协议
/// PingPong service protocol
protocol PingPongProviding {
    /// 并发测试多个连接地址的可达性
    /// Test reachability of multiple connection URLs concurrently
    func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String]

    /// 按连接类型优先级竞速，返回最优可达连接（首个最高优先级可达即返回）
    /// Race all URLs by connection type priority, return the best reachable connection
    func pingpongFirst(connections: [ConnectionType: [String]]) async -> (type: ConnectionType, url: String)?

    /// 测试单个 URL 的可达性
    /// Test reachability of a single URL
    func pingpong(url: String) async -> Bool
}
