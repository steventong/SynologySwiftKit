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

    /// 设备连接提供者
    /// Device connection provider
    public let connectionProvider: DeviceConnectionProviding

    /// API 信息提供者（延迟设置以解决循环依赖）
    /// API info provider (lazy set to resolve circular dependency)
    var apiInfoProvider: ApiInfoProviding?

    // MARK: - Initialization

    /// 初始化 API 客户端
    /// Initialize API client
    /// - Parameter connectionProvider: 设备连接提供者
    init(connectionProvider: DeviceConnectionProviding) {
        self.connectionProvider = connectionProvider
    }

    // MARK: - Public Methods

    /// 发送请求并解码响应
    /// Send request and decode response
    /// 通用请求方法
    public func request<T: Decodable>(_ endpoint: ApiEndpoint, rawResponse: Bool = false)
        async throws -> T
    {
        if rawResponse {
            // 返回原始响应
            return try await sendApiRequest(
                endpoint: endpoint,
                resultType: T.self,
                checkResultIsSuccess: { _ in true },
                parseErrorCode: { _ in nil }
            )
        } else {
            // 解包数据 (默认)
            let response = try await sendApiRequest(
                endpoint: endpoint,
                resultType: SynologyResponse<T>.self,
                checkResultIsSuccess: { $0.success },
                parseErrorCode: { $0.error?.code }
            )
            return try response.unwrap()
        }
    }

    /// 发送请求（无返回值）
    /// Send request without return value
    func request(_ endpoint: ApiEndpoint) async throws {
        let _: EmptyData = try await request(endpoint, rawResponse: false)
    }

    /// 发送请求并返回 Result 类型（带数据）
    /// Send request and return Result type (with data)
    func requestResult<T: Decodable>(_ endpoint: ApiEndpoint) async -> Result<T, Error> {
        do {
            let data: T = try await request(endpoint)
            return .success(data)
        } catch {
            return .failure(error)
        }
    }

    /// 发送请求并返回 Result 类型（无返回值）
    /// Send request and return Result type (without return value)
    func requestResult(_ endpoint: ApiEndpoint) async -> Result<Void, Error> {
        do {
            try await request(endpoint)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// 构建请求 URL（不发送请求）
    /// Build request URL (without sending request)
    func buildUrl(_ endpoint: ApiEndpoint) throws -> URL {
        try buildApiUrlWithQueryParameters(endpoint: endpoint)
    }

    // MARK: - Private Methods

    /// 创建 URLSession
    private func createSession(timeout: TimeInterval) -> URLSession {
        if let connectionUrl = connectionProvider.getCurrentConnectionUrl(),
            connectionUrl.type == .custom_domain, connectionUrl.url.hasPrefix("https://"),
            let url = URL(string: connectionUrl.url)
        {
            return URLSessionFactory.createSession(
                timeoutIntervalForRequest: timeout, trustedSSLDomain: url.host)
        }
        return URLSessionFactory.createSession(timeoutIntervalForRequest: timeout)
    }

    /// 解析 Endpoint 信息
    private func resolveEndpoint(_ endpoint: ApiEndpoint) throws -> (
        name: String, method: String, version: Int, parameters: [String: Any], apiPath: String,
        requireAuthCookie: Bool, requireAuthQuery: Bool
    ) {
        // 自定义路径端点
        if endpoint.isCustomPath {
            return (
                name: endpoint.apiName,
                method: "",
                version: 1,
                parameters: endpoint.parameters,
                apiPath: endpoint.fullPath ?? "",
                requireAuthCookie: true,
                requireAuthQuery: false
            )
        }

        guard let apiInfoProvider else {
            throw SynologyError.api(.hostNotConfigured)
        }

        // 获取 API 信息
        let apiName = endpoint.apiName
        let fetchedApiInfo = try apiInfoProvider.getApiInfoByApiName(apiName: apiName)
        let apiVersion = min(
            max(fetchedApiInfo.minVersion, endpoint.version), fetchedApiInfo.maxVersion)
        let mergedParameters = endpoint.parameters.merging([
            "api": apiName,
            "version": apiVersion,
            "method": endpoint.method,
        ]) { current, _ in current }

        let apiPath: String
        if let customPath = endpoint.pathSuffix {
            apiPath = "/webapi/\(fetchedApiInfo.path)\(customPath)"
        } else {
            apiPath = "/webapi/\(fetchedApiInfo.path)"
        }

        return (
            name: apiName,
            method: endpoint.method,
            version: apiVersion,
            parameters: mergedParameters,
            apiPath: apiPath,
            requireAuthCookie: endpoint.sidOnCookie ?? endpoint.requireAuthCookie,
            requireAuthQuery: endpoint.sidOnQuery ?? endpoint.requireQuerySid
        )
    }

    /// 发送 API 请求
    private func sendApiRequest<Value: Decodable>(
        endpoint: ApiEndpoint,
        resultType: Value.Type = Value.self,
        checkResultIsSuccess: (Value) -> Bool,
        parseErrorCode: (Value) -> Int?
    ) async throws -> Value {
        let resolved = try resolveEndpoint(endpoint)
        let apiUrl = try buildApiUrl(apiPath: resolved.apiPath)

        // 构建请求头
        var headers: [String: String] = [:]
        if let cookie = try buildAuthCookieHeader(
            name: resolved.name,
            method: resolved.method,
            parameters: resolved.parameters,
            requireAuthCookie: resolved.requireAuthCookie
        ) {
            headers["Cookie"] = cookie
        }

        // 发送请求
        let response = try await sendHttpRequest(
            endpoint: endpoint,
            resolved: resolved,
            apiUrl: apiUrl,
            headers: headers,
            resultType: resultType
        )

        // 检查业务状态
        if checkResultIsSuccess(response) {
            return response
        }

        // 处理错误
        guard let errorCode = parseErrorCode(response) else {
            throw SynologyError.api(
                .businessError(code: -1, message: "Unknown error, fetch errorCode fail"))
        }

        try handleErrorCode(errorCode)
        throw SynologyError.api(
            .businessError(code: errorCode, message: "errorCode = \(errorCode)"))
    }

    /// 发送 HTTP 请求
    private func sendHttpRequest<Value: Decodable>(
        endpoint: ApiEndpoint,
        resolved: (
            name: String, method: String, version: Int, parameters: [String: Any], apiPath: String,
            requireAuthCookie: Bool, requireAuthQuery: Bool
        ),
        apiUrl: URL,
        headers: [String: String]?,
        resultType: Value.Type = Value.self
    ) async throws -> Value {
        let session = createSession(timeout: endpoint.timeout)
        var request: URLRequest
        var requestUrl: URL = apiUrl
        let startTime = Date()

        // 构建基础参数
        var parameters = resolved.parameters
        parameters["api"] = resolved.name
        if !resolved.method.isEmpty {
            parameters["method"] = resolved.method
            parameters["version"] = resolved.version
        }

        // 添加 sid 参数
        if let sid = try buildAuthQueryParameter(
            name: resolved.name,
            method: resolved.method,
            requireAuthQuery: resolved.requireAuthQuery
        ) {
            parameters["_sid"] = sid
        }

        switch endpoint.httpMethod {
        case .get:
            guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
                throw SynologyError.api(.hostNotConfigured)
            }
            components.queryItems = parameters.sorted {
                if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
                if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
                return $0.key < $1.key
            }.map { URLQueryItem(name: $0.key, value: "\($0.value)") }

            guard let url = components.url else {
                throw SynologyError.api(.hostNotConfigured)
            }
            requestUrl = url
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
            }.map { "\($0.key)=\(UrlUtils.urlEncode("\($0.value)"))" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
        }

        // 添加请求头
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SynologyError.network(
                    .connectionFailed(
                        underlying: NSError(
                            domain: "", code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])))
            }

            NetworkLogger.logResponse(
                url: requestUrl,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields,
                data: data,
                duration: duration
            )

            guard (200...299).contains(httpResponse.statusCode) else {
                throw SynologyError.network(.httpError(statusCode: httpResponse.statusCode))
            }

            do {
                return try JSONDecoderProvider.shared.decode(Value.self, from: data)
            } catch {
                Logger.error(
                    "JSON decode error: \(error), data: \(String(data: data, encoding: .utf8) ?? "nil")"
                )
                throw SynologyError.network(.responseEmpty)
            }
        } catch let error as SynologyError {
            let duration = Date().timeIntervalSince(startTime)
            NetworkLogger.logError(url: requestUrl, error: error, duration: duration)
            throw error
        } catch let urlError as URLError {
            let duration = Date().timeIntervalSince(startTime)
            NetworkLogger.logError(url: requestUrl, error: urlError, duration: duration)
            try handleURLError(urlError)
            throw SynologyError.network(
                .connectionFailed(
                    underlying: NSError(
                        domain: "", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: urlError.localizedDescription])))
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            NetworkLogger.logError(url: requestUrl, error: error, duration: duration)
            throw SynologyError.network(
                .connectionFailed(
                    underlying: NSError(
                        domain: "", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])))
        }
    }

    /// 构建 API URL
    private func buildApiUrl(apiPath: String) throws -> URL {
        if let connection = connectionProvider.getCurrentConnectionUrl(),
            let connectionURL = URLComponents(string: "\(connection.url)\(apiPath)")?.url
        {
            return connectionURL
        }
        throw SynologyError.api(.hostNotConfigured)
    }

    /// 构建带查询参数的 URL
    private func buildApiUrlWithQueryParameters(endpoint: ApiEndpoint) throws -> URL {
        let resolved = try resolveEndpoint(endpoint)
        let apiUrl = try buildApiUrl(apiPath: resolved.apiPath)

        var parameters = resolved.parameters
        parameters["api"] = resolved.name
        if !resolved.method.isEmpty {
            parameters["method"] = resolved.method
            parameters["version"] = resolved.version
        }

        if let sid = try buildAuthQueryParameter(
            name: resolved.name,
            method: resolved.method,
            requireAuthQuery: resolved.requireAuthQuery
        ) {
            parameters["_sid"] = sid
        }

        guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
            throw SynologyError.api(.hostNotConfigured)
        }

        components.queryItems = parameters.sorted {
            if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
            if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
            return $0.key < $1.key
        }.map { URLQueryItem(name: $0.key, value: "\($0.value)") }

        guard let requestUrl = components.url else {
            throw SynologyError.api(.hostNotConfigured)
        }

        return requestUrl
    }

    /// 构建 Cookie 请求头
    private func buildAuthCookieHeader(
        name: String, method: String, parameters: [String: Any], requireAuthCookie: Bool
    ) throws -> String? {
        if requireAuthCookie {
            guard
                let sid = UserDefaults.standard.string(
                    forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
            else {
                Logger.error("接口: \(name) \(method) 必须配置 sid/did cookie，但 session 不存在。")
                throw SynologyError.api(
                    .invalidSession(code: 0, message: "session invalid, sid not exist"))
            }

            if let did = UserDefaults.standard.string(
                forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            {
                return "id=\(sid); did=\(did)"
            }
            return "id=\(sid)"
        } else if let sid = parameters["sid"] {
            if let did = parameters["did"] {
                return "id=\(sid); did=\(did)"
            }
            return "id=\(sid)"
        }
        return nil
    }

    /// 构建查询参数中的 sid
    private func buildAuthQueryParameter(name: String, method: String, requireAuthQuery: Bool)
        throws -> String?
    {
        if requireAuthQuery {
            guard
                let sid = UserDefaults.standard.string(
                    forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
            else {
                Logger.error("接口: \(name) \(method) 必须配置 sid 参数，但 session 不存在。")
                throw SynologyError.api(
                    .invalidSession(code: 0, message: "session invalid, sid not exist"))
            }
            return sid
        }
        return nil
    }

    /// 处理 URL 错误
    private func handleURLError(_ error: URLError) throws {
        switch error.code {
        case .secureConnectionFailed:
            throw SynologyError.network(.sslFailed(error.localizedDescription))
        case .cannotFindHost:
            throw SynologyError.network(.hostNotFound(error.localizedDescription))
        default:
            throw SynologyError.network(
                .connectionFailed(
                    underlying: NSError(
                        domain: "", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])))
        }
    }

    /// 处理业务错误码
    private func handleErrorCode(_ errorCode: Int) throws {
        let sessionErrorCodes: Set<Int> = [105, 106, 107, 119]

        if sessionErrorCodes.contains(errorCode) {
            let message = SynologyErrorMapper.description(for: errorCode) ?? "Session error"
            throw SynologyError.api(.invalidSession(code: errorCode, message: message))
        }

        if errorCode >= 120 && errorCode <= 149 {
            throw SynologyError.api(
                .businessError(code: errorCode, message: "Preserve for other purpose."))
        }

        let message = SynologyErrorMapper.description(for: errorCode) ?? "errorCode = \(errorCode)"
        throw SynologyError.api(.businessError(code: errorCode, message: message))
    }
}

// MARK: - Helper Types

/// 空数据类型（用于无返回值的请求）
/// Empty data type (for requests without return value)
public struct EmptyData: Decodable {}
