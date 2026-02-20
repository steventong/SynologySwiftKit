//
//  ApiClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiClient

/// 网络请求客户端（支持依赖注入）
/// Network request client (supports dependency injection)
///
/// 使用示例 / Usage example:
/// ```swift
/// let result: PinListResult = try await ApiClient.shared.request(
///     ApiEndpoint(api: SynologyApi.AudioStation.pin, method: "list", parameters: ["limit": 10])
/// )
/// ```
final class ApiClient: ApiClientProviding {
    // MARK: - Dependencies

    // MARK: - internal State

    private let httpTransport: HTTPTransporting

    /// 网络拦截器链
    private var interceptors: [RequestInterceptor] = []

    /// API 信息提供者（延迟设置以解决循环依赖）
    /// API info provider (lazy set to resolve circular dependency)
    var apiInfoProvider: ApiInfoProviding?

    /// 当前连接信息
    /// Current connection info
    private(set) var connection: (type: ConnectionType, url: String)?

    /// 当前会话信息
    /// Current session info
    private(set) var session: (sid: String, did: String?)?

    // MARK: - Initialization

    /// 初始化 API 客户端
    /// Initialize API client
    /// - Parameter httpTransport: HTTP transport adapter
    init(httpTransport: HTTPTransporting = SwiftHttpClientTransport()) {
        self.httpTransport = httpTransport
    }

    /// 注册拦截器
    func addInterceptor(_ interceptor: RequestInterceptor) {
        interceptors.append(interceptor)
    }

    /// 构建请求 URL（不发送请求）
    /// Build request URL (without sending request)
    public func buildUrl(_ endpoint: ApiEndpoint) async throws -> URL {
        try await buildApiUrlWithQueryParameters(endpoint: endpoint)
    }

    // MARK: - Public Methods

    /// 默认请求（解包数据）
    public func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T {
        try await request(endpoint, rawResponse: false)
    }

    /// 发送请求并解码响应
    /// Send request and decode response
    /// 通用请求方法
    public func request<T: Decodable>(_ endpoint: ApiEndpoint, rawResponse: Bool = false) async throws -> T {
        if rawResponse {
            // 返回原始响应
            return try await sendApiRequest(endpoint: endpoint, resultType: T.self, checkResultIsSuccess: { _ in true }, parseErrorCode: { _ in nil })
        } else {
            // 解包数据 (默认)
            let response = try await sendApiRequest(endpoint: endpoint, resultType: SynologyResponse<T>.self, checkResultIsSuccess: { $0.success }, parseErrorCode: { $0.error?.code })
            return try response.unwrap()
        }
    }

    /// 发送原始 HTTP 请求
    /// Send raw HTTP request (non-DSM API scenarios)
    public func request<T: Decodable>(url: URL, httpMethod: HTTPMethod = .get, headers: [String: String]? = nil, body: Data? = nil, timeout: TimeInterval = 10) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.httpBody = body
        headers?.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        return try await executeRequest(request: request, endpoint: rawEndpoint, timeout: timeout, trustedSSLDomain: nil)
    }
}

extension ApiClient {
    /// 更新连接信息
    /// Update connection info
    public func updateConnection(type: ConnectionType, url: String) {
        connection = (type, url)
    }

    /// 更新会话信息
    /// Update session info
    public func updateSession(sid: String, did: String?) {
        session = (sid, did)
    }

    /// 清除会话
    /// Clear session
    public func clearSession() {
        session = nil
    }
}

extension ApiClient {
    // MARK: - Private Methods

    private func trustedSSLDomainForCurrentConnection() async -> String? {
        guard let connection, connection.type == .custom_domain, connection.url.hasPrefix("https://"), let url = URL(string: connection.url) else {
            return nil
        }
        return url.host
    }

    /// 解析 Endpoint 信息
    private func resolveEndpoint(_ endpoint: ApiEndpoint) async throws -> (name: String, method: String, version: Int, parameters: ApiParameters, apiPath: String, requireAuthCookie: Bool, requireAuthQuery: Bool) {
        // 自定义路径端点
        if endpoint.isCustomPath {
            return (name: endpoint.apiName,
                    method: endpoint.method,
                    version: endpoint.version,
                    parameters: endpoint.parameters,
                    apiPath: endpoint.fullPath ?? "",
                    requireAuthCookie: endpoint.sidOnCookie ?? endpoint.requireAuthCookie,
                    requireAuthQuery: endpoint.sidOnQuery ?? endpoint.requireQuerySid)
        }

        guard let apiInfoProvider else {
            throw SynologyError.network(message: "Host not configured")
        }

        // 获取 API 信息
        let apiName = endpoint.apiName
        let fetchedApiInfo = try await apiInfoProvider.getApiInfoByApiName(apiName: apiName)

        let apiVersion = fetchApiVersion(version: endpoint.version, apiMinVersion: fetchedApiInfo.minVersion, apiMaxVersion: fetchedApiInfo.maxVersion)

        let mergedParameters = endpoint.parameters.merging([
            "api": .string(apiName),
            "version": .int(apiVersion),
            "method": .string(endpoint.method),
        ]) { current, _ in current }

        let apiPath: String
        if let customPath = endpoint.pathSuffix {
            apiPath = "/webapi/\(fetchedApiInfo.path)\(customPath)"
        } else {
            apiPath = "/webapi/\(fetchedApiInfo.path)"
        }

        return (name: apiName,
                method: endpoint.method,
                version: apiVersion,
                parameters: mergedParameters,
                apiPath: apiPath,
                requireAuthCookie: endpoint.sidOnCookie ?? endpoint.requireAuthCookie,
                requireAuthQuery: endpoint.sidOnQuery ?? endpoint.requireQuerySid
        )
    }

    /// 发送 API 请求
    private func sendApiRequest<Value: Decodable>(endpoint: ApiEndpoint, resultType: Value.Type = Value.self,
                                                  checkResultIsSuccess: (Value) -> Bool, parseErrorCode: (Value) -> Int?) async throws -> Value {
        let resolved = try await resolveEndpoint(endpoint)
        let apiUrl = try await buildApiUrl(apiPath: resolved.apiPath)

        // 构建请求头
        var headers: [String: String] = [:]
        if let cookie = try await buildAuthCookieHeader(name: resolved.name, method: resolved.method,
                                                        parameters: resolved.parameters,
                                                        requireAuthCookie: resolved.requireAuthCookie) {
            headers["Cookie"] = cookie
        }

        // 发送请求
        let response = try await sendHttpRequest(endpoint: endpoint, resolved: resolved, apiUrl: apiUrl, headers: headers, resultType: resultType)

        // 检查业务状态
        if checkResultIsSuccess(response) {
            return response
        }

        // 解析错误码
        guard let errorCode = parseErrorCode(response) else {
            throw SynologyError.api(code: -1, message: "Unknown error, fetch errorCode fail")
        }

        // 处理常见错误码
        try handleErrorCode(errorCode)

        // 其他业务错误码
        throw SynologyError.api(code: errorCode, message: "errorCode = \(errorCode)")
    }

    /// 发送 API 请求
    private func sendHttpRequest<Value: Decodable>(endpoint: ApiEndpoint,
                                                   resolved: (name: String, method: String, version: Int, parameters: ApiParameters, apiPath: String, requireAuthCookie: Bool, requireAuthQuery: Bool),
                                                   apiUrl: URL, headers: [String: String]?,
                                                   resultType: Value.Type = Value.self) async throws -> Value {
        var request: URLRequest

        // 构建基础参数
        var parameters = resolved.parameters
        parameters["api"] = .string(resolved.name)
        if !resolved.method.isEmpty {
            parameters["method"] = .string(resolved.method)
            parameters["version"] = .int(resolved.version)
        }

        // 添加 sid 参数
        if let sid = try await buildAuthQueryParameter(name: resolved.name, method: resolved.method, requireAuthQuery: resolved.requireAuthQuery) {
            parameters["_sid"] = .string(sid)
        }

        switch endpoint.httpMethod {
        case .get:
            guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
                throw SynologyError.network(message: "Host not configured")
            }
            components.queryItems = parameters.sorted {
                if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
                if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
                return $0.key < $1.key
            }.map { URLQueryItem(name: $0.key, value: $0.value.stringValue) }

            guard let url = components.url else {
                throw SynologyError.network(message: "Host not configured")
            }
            request = URLRequest(url: url)
            request.httpMethod = "GET"

        case .post, .put, .delete:
            request = URLRequest(url: apiUrl)
            request.httpMethod = endpoint.httpMethod.rawValue
            request.setValue(
                "application/x-www-form-urlencoded; charset=UTF-8",
                forHTTPHeaderField: "Content-Type")

            let bodyString = parameters.sorted {
                if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
                if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
                return $0.key < $1.key
            }.map { "\($0.key)=\(UrlUtils.urlEncode($0.value.stringValue))" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
        }

        // 添加请求头
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return try await executeRequest(
            request: request,
            endpoint: endpoint,
            timeout: endpoint.timeout,
            trustedSSLDomain: await trustedSSLDomainForCurrentConnection()
        )
    }

    /// 构建 API URL
    private func buildApiUrl(apiPath: String) async throws -> URL {
        if let connection, let connectionURL = URLComponents(string: "\(connection.url)\(apiPath)")?.url {
            return connectionURL
        }
        throw SynologyError.network(message: "Host not configured")
    }

    /// 构建带查询参数的 URL
    private func buildApiUrlWithQueryParameters(endpoint: ApiEndpoint) async throws -> URL {
        let resolved = try await resolveEndpoint(endpoint)
        let apiUrl = try await buildApiUrl(apiPath: resolved.apiPath)

        var parameters = resolved.parameters
        parameters["api"] = .string(resolved.name)
        if !resolved.method.isEmpty {
            parameters["method"] = .string(resolved.method)
            parameters["version"] = .int(resolved.version)
        }

        if let sid = try await buildAuthQueryParameter(
            name: resolved.name,
            method: resolved.method,
            requireAuthQuery: resolved.requireAuthQuery
        ) {
            parameters["_sid"] = .string(sid)
        }

        guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
            throw SynologyError.network(message: "Host not configured")
        }

        components.queryItems = parameters.sorted {
            if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
            if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
            return $0.key < $1.key
        }.map { URLQueryItem(name: $0.key, value: $0.value.stringValue) }

        guard let requestUrl = components.url else {
            throw SynologyError.network(message: "Host not configured")
        }

        return requestUrl
    }

    /// 构建 Cookie 请求头
    private func buildAuthCookieHeader(name: String, method: String, parameters: ApiParameters, requireAuthCookie: Bool) async throws -> String? {
        if requireAuthCookie {
            guard let session = session
            else {
                Logger.error("接口: \(name) \(method) 必须配置 sid/did cookie，但 session 不存在。")
                throw SynologyError.sessionExpired(code: 0, message: "session invalid, sid not exist")
            }

            if let did = session.did {
                return "id=\(session.sid); did=\(did)"
            }
            return "id=\(session.sid)"
        } else if let sid = parameters["sid"]?.stringValue {
            if let did = parameters["did"]?.stringValue {
                return "id=\(sid); did=\(did)"
            }
            return "id=\(sid)"
        }
        return nil
    }

    /// 构建查询参数中的 sid
    private func buildAuthQueryParameter(name: String, method: String, requireAuthQuery: Bool) async throws -> String? {
        if requireAuthQuery {
            guard let session = session
            else {
                Logger.error("接口: \(name) \(method) 必须配置 sid 参数，但 session 不存在。")
                throw SynologyError.sessionExpired(code: 0, message: "session invalid, sid not exist")
            }
            return session.sid
        }
        return nil
    }

    /// 处理 URL 错误
    private func handleURLError(_ error: URLError) throws {
        switch error.code {
        case .secureConnectionFailed:
            Logger.error("secureConnectionFailed ssl error, \(error.localizedDescription)")
            throw SynologyError.network(message: "Connection failed: \(error.localizedDescription)")
        case .cannotFindHost:
            Logger.error("cannotFindHost error, \(error.localizedDescription)")
            throw SynologyError.network(message: "Connection failed: \(error.localizedDescription)")
        case .timedOut:
            Logger.error("timeout error, \(error.localizedDescription)")
            throw SynologyError.network(message: "Request timeout")
        default:
            Logger.error("http error, \(error.localizedDescription)")
            throw SynologyError.network(message: error.localizedDescription)
        }
    }

    /// 处理业务错误码
    private func handleErrorCode(_ errorCode: Int) throws {
        let sessionErrorCodes: Set<Int> = [105, 106, 107, 119]

        if sessionErrorCodes.contains(errorCode) {
            let message = SynologyErrorCodeMapper.description(for: errorCode) ?? "Session error"
            throw SynologyError.sessionExpired(code: errorCode, message: message)
        }

        if errorCode >= 120 && errorCode <= 149 {
            throw SynologyError.api(code: errorCode, message: "Preserve for other purpose.")
        }

        let message = SynologyErrorCodeMapper.description(for: errorCode) ?? "errorCode = \(errorCode)"
        throw SynologyError.api(code: errorCode, message: message)
    }

    /// 获取适配的 API 版本
    private func fetchApiVersion(version: Int, apiMinVersion: Int, apiMaxVersion: Int) -> Int {
        return min(max(apiMinVersion, version), apiMaxVersion)
    }

    // MARK: - Interceptors

    private var rawEndpoint: ApiEndpoint {
        ApiEndpoint(api: SynologyApi.Core.INFO, method: "")
    }

    private func applyRequestInterceptors(_ request: URLRequest, endpoint: ApiEndpoint, context: inout RequestContext) async throws -> URLRequest {
        var current = request
        for interceptor in interceptors {
            if let contextAware = interceptor as? RequestInterceptorWithContext {
                current = try await contextAware.adapt(current, for: endpoint, context: &context)
            } else {
                current = try await interceptor.adapt(current, for: endpoint)
            }
        }
        return current
    }

    private func applyResponseInterceptors(_ result: Result<(Data, URLResponse), Error>, endpoint: ApiEndpoint, context: inout RequestContext) async throws -> Result<(Data, URLResponse), Error> {
        var current = result
        for interceptor in interceptors.reversed() {
            if let contextAware = interceptor as? RequestInterceptorWithContext {
                current = try await contextAware.process(current, for: endpoint, context: &context)
            } else {
                current = try await interceptor.process(current, for: endpoint)
            }
        }
        return current
    }

    // MARK: - Shared Execution

    private func executeRequest<Value: Decodable>(request: URLRequest, endpoint: ApiEndpoint, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> Value {
        var context = RequestContext()
        var currentRequest = request

        currentRequest = try await applyRequestInterceptors(currentRequest, endpoint: endpoint, context: &context)

        do {
            let (data, response) = try await httpTransport.send(currentRequest, timeout: timeout, trustedSSLDomain: trustedSSLDomain)

            context.duration = Date().timeIntervalSince(context.startTime)

            let processed = try await applyResponseInterceptors(.success((data, response)), endpoint: endpoint, context: &context)
            let processedData: Data
            let processedResponse: URLResponse
            switch processed {
            case let .success(value):
                processedData = value.0
                processedResponse = value.1
            case let .failure(error):
                throw error
            }

            guard let httpResponse = processedResponse as? HTTPURLResponse else {
                throw SynologyError.network(message: "Invalid response")
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw SynologyError.network(message: "Invalid HTTP status: \(httpResponse.statusCode)")
            }

            do {
                return try JSONDecoderProvider.shared.decode(Value.self, from: processedData)
            } catch {
                Logger.error("JSON decode error: \(error), data: \(String(data: processedData, encoding: .utf8) ?? "nil")")
                throw SynologyError.network(message: "Decoding failed: \(error.localizedDescription)")
            }
        } catch let error as SynologyError {
            context.duration = Date().timeIntervalSince(context.startTime)
            _ = try await applyResponseInterceptors(.failure(error), endpoint: endpoint, context: &context)
            throw error
        } catch let urlError as URLError {
            context.duration = Date().timeIntervalSince(context.startTime)
            _ = try await applyResponseInterceptors(.failure(urlError), endpoint: endpoint, context: &context)
            try handleURLError(urlError)
            throw SynologyError.network(message: urlError.localizedDescription)
        } catch {
            context.duration = Date().timeIntervalSince(context.startTime)
            _ = try await applyResponseInterceptors(.failure(error), endpoint: endpoint, context: &context)
            throw SynologyError.network(message: error.localizedDescription)
        }
    }
}

// MARK: - Helper Types

/// 空数据类型（用于无返回值的请求）
/// Empty data type (for requests without return value)
public struct EmptyData: Decodable {}
