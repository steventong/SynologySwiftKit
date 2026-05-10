//
//  ApiClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiClient

final class ApiClient: ApiClientProviding {
    // MARK: - Dependencies

    // MARK: - internal State

    private let state = ApiClientState()
    private let executor: ApiRequestExecutor
    private let envelopeDecoder = SynologyEnvelopeDecoder()

    private lazy var endpointResolver = ApiEndpointResolver(
        apiInfoProvider: { [weak state] in state?.apiInfoProvider }
    )

    private lazy var requestFactory = ApiRequestFactory(
        connectionProvider: { [weak state] in state?.connection },
        sessionProvider: { [weak state] in state?.session }
    )

    /// API 信息提供者（延迟设置以解决循环依赖）
    /// API info provider (lazy set to resolve circular dependency)
    var apiInfoProvider: ApiInfoProviding? {
        get { state.apiInfoProvider }
        set { state.apiInfoProvider = newValue }
    }

    /// 当前连接信息
    /// Current connection info
    var connection: (type: ConnectionType, url: String)? {
        state.connection
    }

    /// 当前会话信息
    /// Current session info
    var session: (sid: String, did: String?)? {
        state.session
    }

    // MARK: - Initialization

    /// 初始化 API 客户端
    /// Initialize API client
    /// - Parameter httpClient: HTTP client implementation
    init(httpClient: HTTPClientProtocol = URLSessionHTTPClient()) {
        executor = ApiRequestExecutor(
            httpClient: httpClient,
            interceptorsProvider: { [weak state] in
                state?.interceptorsSnapshot() ?? []
            }
        )
    }

    /// 注册拦截器
    func addInterceptor(_ interceptor: RequestInterceptor) {
        state.addInterceptor(interceptor)
    }

    /// 构建请求 URL（不发送请求）
    /// Build request URL (without sending request)
    func buildUrl(_ endpoint: ApiEndpoint) async throws -> URL {
        try await buildApiUrlWithQueryParameters(endpoint: endpoint)
    }

    // MARK: - Public Methods

    /// 默认请求（解包数据）
    func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T {
        let response: SynologyResponse<T> = try await requestEnvelope(endpoint)
        if let errorCode = envelopeDecoder.errorCode(response) {
            throw SynologyApiError.toSynologyError(from: errorCode)
        }
        return try envelopeDecoder.unwrap(response)
    }

    /// Send request and decode the Synology response envelope without unwrapping data.
    func requestEnvelope<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T {
        try await sendApiRequest(endpoint: endpoint, resultType: T.self)
    }

    /// 发送原始 HTTP 请求
    /// Send raw HTTP request (non-DSM API scenarios)
    func request<T: Decodable>(url: URL, httpMethod: HTTPMethod = .get, headers: [String: String]? = nil, body: Data? = nil, timeout: TimeInterval = 10) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.httpBody = body
        headers?.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        return try await executor.execute(
            T.self,
            request: request,
            endpoint: rawEndpoint,
            timeout: timeout,
            trustedSSLDomain: nil
        )
    }
}

extension ApiClient {
    
    /// 更新连接信息
    /// Update connection info
    func updateConnection(type: ConnectionType, url: String) {
        state.updateConnection(type: type, url: url)
    }

    /// 更新会话信息
    /// Update session info
    func updateSession(sid: String, did: String?) {
        state.updateSession(sid: sid, did: did)
    }

    /// 清除会话
    /// Clear session
    func clearSession() {
        state.clearSession()
    }
}

extension ApiClient {
    // MARK: - Private Methods

    /// 发送 API 请求
    private func sendApiRequest<Value: Decodable>(endpoint: ApiEndpoint, resultType: Value.Type = Value.self) async throws -> Value {
        let resolved = try await endpointResolver.resolve(endpoint)
        let request = try await requestFactory.makeRequest(endpoint: endpoint, resolved: resolved)
        return try await executor.execute(
            Value.self,
            request: request,
            endpoint: endpoint,
            timeout: endpoint.timeout,
            trustedSSLDomain: requestFactory.trustedSSLDomainForCurrentConnection()
        )
    }

    /// 构建带查询参数的 URL
    private func buildApiUrlWithQueryParameters(endpoint: ApiEndpoint) async throws -> URL {
        let resolved = try await endpointResolver.resolve(endpoint)
        return try await requestFactory.makeURL(endpoint: endpoint, resolved: resolved)
    }

    private var rawEndpoint: ApiEndpoint {
        ApiEndpoint(api: SynologyApi.Core.INFO, method: "")
    }
}

// MARK: - Helper Types

/// 空数据类型（用于无返回值的请求）
/// Empty data type (for requests without return value)
struct EmptyData: Decodable {}
