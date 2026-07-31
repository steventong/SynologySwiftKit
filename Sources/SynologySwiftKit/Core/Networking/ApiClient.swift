//
//  ApiClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import SwiftHttpClient

// MARK: - ApiClient

final class ApiClient: ApiClientProviding {
    // MARK: - Dependencies

    // MARK: - internal State

    private let state: ApiClientState
    private let executor: ApiRequestExecutor
    private let envelopeDecoder = SynologyEnvelopeDecoder()
    private let endpointResolver: ApiEndpointResolver
    private let requestFactory: ApiRequestFactory
    private let certificateTrustStore: ServerCertificateTrustStore

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
    /// - Parameter httpClientFactory: HTTP client factory
    init(
        httpClientFactory: @escaping SynologyHTTPClientFactory = defaultSynologyHTTPClientFactory,
        keyValueStorage: KeyValueStorage = StorageService()
    ) {
        let state = ApiClientState()
        let certificateTrustStore = ServerCertificateTrustStore(storage: keyValueStorage)
        self.state = state
        self.certificateTrustStore = certificateTrustStore
        endpointResolver = ApiEndpointResolver(
            apiInfoProvider: { [weak state] in state?.apiInfoProvider }
        )
        requestFactory = ApiRequestFactory(
            connectionProvider: { [weak state] in state?.connection },
            sessionProvider: { [weak state] in state?.session }
        )
        executor = ApiRequestExecutor(
            httpClientFactory: httpClientFactory,
            interceptorsProvider: { [weak state] in
                state?.interceptorsSnapshot() ?? []
            },
            sessionSummaryProvider: { [weak state] in
                state?.sessionSummary ?? Logger.sessionSummary(sid: nil, did: nil)
            },
            connectionSummaryProvider: { [weak state] in
                state?.connectionSummary ?? Logger.connectionSummary(url: nil)
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
        let (response, request): (SynologyResponse<T>, URLRequest) = try await sendApiRequestWithRequest(
            endpoint: endpoint,
            resultType: SynologyResponse<T>.self
        )
        if let errorCode = envelopeDecoder.errorCode(response) {
            logApiErrorResponse(code: errorCode, response: response, request: request, endpoint: endpoint)
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
            serverTrustPolicy: serverTrustPolicy(for: url)
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

    func approveServerCertificate(_ certificate: SynologyServerCertificate) {
        certificateTrustStore.approve(certificate)
    }

    func approvedServerCertificateFingerprint(forHost host: String) -> String? {
        certificateTrustStore.approvedFingerprint(forHost: host)
    }
}

extension ApiClient {
    // MARK: - Private Methods

    /// 发送 API 请求
    private func sendApiRequest<Value: Decodable>(endpoint: ApiEndpoint, resultType: Value.Type = Value.self) async throws -> Value {
        let (value, _) = try await sendApiRequestWithRequest(endpoint: endpoint, resultType: resultType)
        return value
    }

    /// 发送 API 请求，并保留原始 URLRequest 供错误诊断使用。
    private func sendApiRequestWithRequest<Value: Decodable>(
        endpoint: ApiEndpoint,
        resultType: Value.Type = Value.self
    ) async throws -> (Value, URLRequest) {
        let resolved = try await endpointResolver.resolve(endpoint)
        let request = try await requestFactory.makeRequest(endpoint: endpoint, resolved: resolved)
        let value = try await executor.execute(
            Value.self,
            request: request,
            endpoint: endpoint,
            timeout: endpoint.timeout,
            serverTrustPolicy: serverTrustPolicy(for: request.url)
        )
        return (value, request)
    }

    /// 构建带查询参数的 URL
    private func buildApiUrlWithQueryParameters(endpoint: ApiEndpoint) async throws -> URL {
        let resolved = try await endpointResolver.resolve(endpoint)
        return try await requestFactory.makeURL(endpoint: endpoint, resolved: resolved)
    }

    private var rawEndpoint: ApiEndpoint {
        ApiEndpoint(api: SynologyApi.Core.INFO, method: "")
    }

    private func serverTrustPolicy(for url: URL?) -> ServerTrustPolicy {
        guard url?.scheme?.lowercased() == "https", let host = url?.host else {
            return .system
        }
        return .userApprovedCertificate(
            host: host,
            sha256Fingerprint: certificateTrustStore.approvedFingerprint(forHost: host)
        )
    }

    private func logApiErrorResponse<T>(
        code: Int,
        response: SynologyResponse<T>,
        request: URLRequest,
        endpoint: ApiEndpoint
    ) {
        let message = SynologyErrorCode(rawValue: code).description
        let errorCodes = response.error?.errors.map(String.init).joined(separator: ",") ?? ""
        let details = [
            "code=\(code)",
            "message=\(message)",
            "nestedErrors=[\(errorCodes)]",
            "api=\(endpoint.apiName)",
            "method=\(endpoint.method)",
            "version=\(endpoint.version)",
            "httpMethod=\(endpoint.httpMethod.rawValue)",
            "parameters=\(sanitizedParameters(endpoint.parameters))",
            "url=\(Logger.sanitizedURLString(request.url))",
            "body=\(Logger.sanitizedBodyString(request.httpBody))",
            "headers=\(Logger.sanitizedHeaders(request.allHTTPHeaderFields))",
            "requiresAuthCookie=\(endpoint.sidOnCookie ?? endpoint.requireAuthCookie)",
            "requiresQuerySid=\(endpoint.sidOnQuery ?? endpoint.requireQuerySid)",
            state.connectionSummary,
            state.sessionSummary,
        ].joined(separator: ", ")

        if code == 105 {
            Logger.warn("ApiClient#request permission denied response, \(details)")
        } else {
            Logger.warn("ApiClient#request api error response, \(details)")
        }
    }

    private func sanitizedParameters(_ parameters: ApiParameters) -> String {
        guard !parameters.isEmpty else {
            return "[:]"
        }
        return parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(sanitizedValue($0.value.stringValue, forKey: $0.key))" }
            .joined(separator: "&")
    }

    private func sanitizedValue(_ value: String, forKey key: String) -> String {
        Logger.sanitizedValue(value, forKey: key)
    }
}

// MARK: - Helper Types

/// 空数据类型（用于无返回值的请求）
/// Empty data type (for requests without return value)
struct EmptyData: Decodable, Sendable {}
