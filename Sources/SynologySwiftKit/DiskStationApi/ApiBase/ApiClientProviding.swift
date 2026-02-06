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
public protocol ApiClientProviding {
    
    var connectionProvider: DeviceConnectionProviding { get }
    
    /// 通用请求方法
    /// - Parameters:
    ///   - rawResponse: 如果为 true，返回原始响应类型(T)；如果为 false，解包 SynologyResponse<T> 返回 data(T)。
    func request<T: Decodable>(_ endpoint: ApiEndpoint, rawResponse: Bool) async throws -> T

    /// 发送请求（无返回值）
    /// Send request without return value
    func request(_ endpoint: ApiEndpoint) async throws

    /// 构建请求 URL（不发送请求）
    /// Build request URL (without sending request)
    func buildUrl(_ endpoint: ApiEndpoint) async throws -> URL

    /// 发送原始 HTTP 请求（非 DSM API 场景）
    /// Send raw HTTP request (non-DSM API scenarios)
    func requestRaw<T: Decodable>(
        url: URL,
        httpMethod: HTTPMethod,
        headers: [String: String]?,
        body: Data?,
        timeout: TimeInterval
    ) async throws -> T
}

extension ApiClientProviding {
    
    /// 默认请求（解包数据）
    public func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T {
        try await request(endpoint, rawResponse: false)
    }

    /// 兼容请求（带 ResultType）
    public func request<T: Decodable>(_ endpoint: ApiEndpoint, resultType: T.Type) async throws -> T {
        try await request(endpoint, rawResponse: false)
    }
}
