//
//  NetworkInterceptor.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// Public request interceptor extension point for SDK users.
public protocol SynologyRequestInterceptor: Sendable {
    func adapt(_ request: URLRequest) async throws -> URLRequest
    func process(_ result: Result<(Data, URLResponse), Error>) async throws -> Result<(Data, URLResponse), Error>
}

public extension SynologyRequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        request
    }

    func process(_ result: Result<(Data, URLResponse), Error>) async throws -> Result<(Data, URLResponse), Error> {
        result
    }
}

struct PublicRequestInterceptorAdapter: RequestInterceptor {
    private let interceptor: any SynologyRequestInterceptor

    init(_ interceptor: any SynologyRequestInterceptor) {
        self.interceptor = interceptor
    }

    func adapt(_ request: URLRequest, for endpoint: ApiEndpoint) async throws -> URLRequest {
        try await interceptor.adapt(request)
    }

    func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint) async throws -> Result<(Data, URLResponse), Error> {
        try await interceptor.process(result)
    }
}

/// 网络请求拦截器协议
/// Protocol for intercepting network requests
protocol RequestInterceptor: Sendable {
    /// 预处理请求 (例如添加 Token, Header)
    /// Pre-process the request (e.g., adding Token, Header)
    func adapt(_ request: URLRequest, for endpoint: ApiEndpoint) async throws -> URLRequest

    /// 处理响应结果 (例如日志记录, 错误重试)
    /// Process the response result (e.g., logging, error retry)
    func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint) async throws -> Result<(Data, URLResponse), Error>
}

/// 请求上下文
struct RequestContext: Sendable {
    let startTime: Date
    var duration: TimeInterval?
    var metadata: [String: String]

    init(startTime: Date = Date(), duration: TimeInterval? = nil, metadata: [String: String] = [:]) {
        self.startTime = startTime
        self.duration = duration
        self.metadata = metadata
    }
}

/// 支持上下文的拦截器（可选实现）
protocol RequestInterceptorWithContext: RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: ApiEndpoint, context: inout RequestContext) async throws -> URLRequest
    func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint, context: inout RequestContext) async throws -> Result<(Data, URLResponse), Error>
}

// 默认实现，方便只需实现部分方法的拦截器
extension RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: ApiEndpoint) async throws -> URLRequest {
        return request
    }

    func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint) async throws -> Result<(Data, URLResponse), Error> {
        return result
    }
}

extension RequestInterceptorWithContext {
    func adapt(_ request: URLRequest, for endpoint: ApiEndpoint, context: inout RequestContext) async throws -> URLRequest {
        return try await adapt(request, for: endpoint)
    }

    func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint, context: inout RequestContext) async throws -> Result<(Data, URLResponse), Error> {
        return try await process(result, for: endpoint)
    }
}
