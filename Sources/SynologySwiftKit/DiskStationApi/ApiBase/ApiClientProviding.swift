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

    /// 发送请求并解码响应
    /// Send request and decode response
    func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T

    /// 发送请求（无返回值）
    /// Send request without return value
    func request(_ endpoint: ApiEndpoint) async throws

    /// 发送请求并返回数据部分
    /// Send request and return data part
    func requestForData<T: Decodable>(_ endpoint: ApiEndpoint, resultType: T.Type) async throws -> T

    /// 发送请求并返回原始结果
    /// Send request and return raw result
    func requestForResult<T: Decodable>(_ endpoint: ApiEndpoint, resultType: T.Type) async throws
        -> T

    /// 构建请求 URL（不发送请求）
    /// Build request URL (without sending request)
    func buildUrl(_ endpoint: ApiEndpoint) throws -> URL
}
