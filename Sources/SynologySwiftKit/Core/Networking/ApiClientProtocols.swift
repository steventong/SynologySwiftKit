//
//  ApiClientProviding.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - Connection Protocols

/// 连接状态查询协议
/// Protocol for querying connection state
protocol ConnectionStateProviding {
    /// 当前连接信息（连接类型 + 服务器地址），未配置时为 nil
    /// Current connection info (type + URL), nil if not configured
    var connection: (type: ConnectionType, url: String)? { get }
}

/// 连接状态更新协议
/// Protocol for updating connection state
protocol ConnectionStateUpdating {
    /// 更新连接信息
    /// Update connection info
    /// - Parameters:
    ///   - type: 连接类型 / Connection type
    ///   - url: 服务器地址 / Server URL
    func updateConnection(type: ConnectionType, url: String)
}

// MARK: - Session Protocols

/// 会话状态查询协议
/// Protocol for querying session state
protocol SessionStateProviding {
    /// 当前会话信息（SID + DID），未配置时为 nil
    /// Current session info (SID + DID), nil if not configured
    var session: (sid: String, did: String?)? { get }
}

/// 会话状态更新协议
/// Protocol for updating session state
protocol SessionStateUpdating {
    /// 更新会话信息
    /// Update session info
    func updateSession(sid: String, did: String?)

    /// 清除当前会话
    /// Clear the current session
    func clearSession()
}

// MARK: - Request Protocols

/// API 请求发送协议
/// Protocol for sending API requests
protocol ApiRequestSending {
    /// 发送 API 请求并解包 data 字段
    /// Send API request and unwrap data field
    func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T

    /// 发送 API 请求并返回完整的 Synology 响应信封（不解包）
    /// Send API request and return full Synology response envelope (without unwrapping)
    func requestEnvelope<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T
}

/// URL 构建协议（不发送请求）
/// Protocol for building request URLs (without sending)
protocol ApiURLBuilding {
    /// 根据端点构建完整请求 URL（含认证参数）
    /// Build full request URL from endpoint (including auth parameters)
    func buildUrl(_ endpoint: ApiEndpoint) async throws -> URL
}

/// 原始 HTTP 请求发送协议（用于非 DSM API 场景）
/// Protocol for sending raw HTTP requests (non-DSM API scenarios)
protocol RawRequestSending {
    /// 发送原始 HTTP 请求
    /// Send raw HTTP request
    func request<T: Decodable>(url: URL, httpMethod: HTTPMethod, headers: [String: String]?, body: Data?, timeout: TimeInterval) async throws -> T
}

// MARK: - Composite Typealias

/// API 端点客户端组合协议（请求发送 + URL 构建）
/// Composite protocol for API endpoint clients (request sending + URL building)
typealias ApiEndpointClient = ApiRequestSending & ApiURLBuilding

/// 完整内部客户端能力集（内部使用，具体服务优先使用更细粒度的协议）
/// Full internal client capability set (prefer narrower protocols in feature services)
typealias ApiClientProviding = ApiRequestSending
    & ApiURLBuilding
    & RawRequestSending
    & ConnectionStateProviding
    & ConnectionStateUpdating
    & SessionStateProviding
    & SessionStateUpdating
