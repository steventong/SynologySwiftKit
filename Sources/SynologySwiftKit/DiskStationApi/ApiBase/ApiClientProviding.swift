//
//  ApiClientProviding.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiClientProviding Protocol

/// API 客户端协议
/// API client protocol
///
/// 定义网络请求的接口，支持依赖注入模式。
/// Defines network request interfaces, supporting dependency injection pattern.
protocol ApiClientProviding {
    /// 当前连接信息
    /// Current connection info
    var connection: (type: ConnectionType, url: String)? { get }

    /// 当前会话信息
    /// Current session info
    var session: (sid: String, did: String?)? { get }

    /// 构建请求 URL（不发送请求）
    /// Build request URL (without sending request)
    func buildUrl(_ endpoint: ApiEndpoint) async throws -> URL

    /// 发送请求并解码响应
    /// Send request and decode response
    func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T

    /// 发送请求并解码响应
    /// Send request and decode response
    func request<T: Decodable>(_ endpoint: ApiEndpoint, rawResponse: Bool) async throws -> T

    /// 发送原始 HTTP 请求
    /// Send raw HTTP request (non-DSM API scenarios)
    func request<T: Decodable>(url: URL, httpMethod: HTTPMethod, headers: [String: String]?, body: Data?, timeout: TimeInterval) async throws -> T

    /// 更新连接信息
    /// Update connection info
    func updateConnection(type: ConnectionType, url: String)

    /// 更新会话信息
    /// Update session info
    func updateSession(sid: String, did: String?)

    /// 清除会话
    /// Clear session
    func clearSession()
}
