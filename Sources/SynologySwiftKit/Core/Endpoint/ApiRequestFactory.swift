import Foundation

// MARK: - ApiRequestFactory

/// API 请求构建工厂
/// API request factory
///
/// 负责将已解析的端点（`ResolvedApiEndpoint`）结合当前连接和会话信息，构建最终的 `URLRequest` 或 `URL`。
/// Responsible for building the final `URLRequest` or `URL` from a resolved endpoint, connection, and session.
///
/// 两种构建模式：
/// Two build modes:
/// - `makeRequest`: 用于正常 API 请求，认证由拦截器注入 / For normal API requests, auth injected by interceptors
/// - `makeURL`: 用于生成公开访问 URL（如封面/流媒体），直接注入 `_sid` / For public URLs (covers/streams), injects `_sid` directly
struct ApiRequestFactory {
    /// 连接信息提供者（弱引用，通过闭包延迟获取）
    /// Connection info provider (lazily fetched via closure)
    let connectionProvider: () -> (type: ConnectionType, url: String)?

    /// 会话信息提供者（弱引用，通过闭包延迟获取）
    /// Session info provider (lazily fetched via closure)
    let sessionProvider: () -> (sid: String, did: String?)?

    /// 构建 URLRequest（用于正常 API 请求）
    /// Build URLRequest for normal API requests
    ///
    /// 认证参数（SID/DID）由拦截器在后续阶段注入，此处仅处理显式传入的 sid 参数。
    /// Auth parameters (SID/DID) are injected by interceptors in later stages; only explicit sid params are handled here.
    /// - Parameters:
    ///   - endpoint: 原始端点（含 HTTP 方法等信息）/ Original endpoint (with HTTP method, etc.)
    ///   - resolved: 已解析的端点（含路径、参数）/ Resolved endpoint (with path and parameters)
    /// - Returns: 构建完成的 URLRequest / Built URLRequest
    /// - Throws: `SynologyError.network` 如果连接地址未配置 / if connection URL is not configured
    func makeRequest(endpoint: ApiEndpoint, resolved: ResolvedApiEndpoint) async throws -> URLRequest {
        let apiUrl = try buildApiUrl(apiPath: resolved.apiPath)
        var request: URLRequest
        var parameters = resolved.parameters

        parameters["api"] = .string(resolved.name)
        if !resolved.method.isEmpty {
            parameters["method"] = .string(resolved.method)
            parameters["version"] = .int(resolved.version)
        }

        switch endpoint.httpMethod {
        case .get:
            request = URLRequest(url: try buildUrl(apiUrl: apiUrl, parameters: parameters))
            request.httpMethod = "GET"

        case .post, .put, .delete:
            request = URLRequest(url: apiUrl)
            request.httpMethod = endpoint.httpMethod.rawValue
            request.setValue(
                "application/x-www-form-urlencoded; charset=UTF-8",
                forHTTPHeaderField: "Content-Type"
            )
            request.httpBody = formURLEncodedBody(parameters: parameters)
        }

        // Explicit sid/did parameters are kept for call sites that provide a detached session.
        if let cookie = buildExplicitCookieHeader(parameters: resolved.parameters) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        return request
    }

    /// 构建公开访问 URL（用于封面、流媒体等需要 _sid 的场景）
    /// Build public access URL (for covers, streams, and other scenarios requiring `_sid`)
    ///
    /// 绕过拦截器，直接将 `_sid` 注入 URL Query，适用于 `WKWebView`、`AVPlayer` 等无法注入 Header 的场景。
    /// Bypasses interceptors and injects `_sid` directly into URL query, suitable for `WKWebView`, `AVPlayer`, etc.
    /// - Parameters:
    ///   - endpoint: 原始端点 / Original endpoint
    ///   - resolved: 已解析的端点 / Resolved endpoint
    /// - Returns: 包含 `_sid` 参数的完整 URL / Complete URL with `_sid` parameter
    /// - Throws: `SynologyError` 如果连接未配置或 Session 不存在 / if connection or session is missing
    func makeURL(endpoint: ApiEndpoint, resolved: ResolvedApiEndpoint) async throws -> URL {
        let apiUrl = try buildApiUrl(apiPath: resolved.apiPath)
        var parameters = resolved.parameters

        // Public URL generation bypasses interceptors, so ambient `_sid` stays here.
        parameters["api"] = .string(resolved.name)
        if !resolved.method.isEmpty {
            parameters["method"] = .string(resolved.method)
            parameters["version"] = .int(resolved.version)
        }

        if let sid = try buildAmbientAuthQueryParameter(
            name: resolved.name,
            method: resolved.method,
            requireAuthQuery: resolved.requireAuthQuery
        ) {
            parameters["_sid"] = .string(sid)
        }

        return try buildUrl(apiUrl: apiUrl, parameters: parameters)
    }

    /// 根据 API 路径构建基础 URL（含 Host + Path，不含 Query）
    /// Build base URL from API path (Host + Path, no Query)
    private func buildApiUrl(apiPath: String) throws -> URL {
        guard let connection = connectionProvider(),
              var components = URLComponents(string: connection.url)
        else {
            throw SynologyError.network(message: "Host not configured")
        }

        let basePath = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = apiPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let combinedPath = [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.percentEncodedPath = combinedPath.isEmpty ? "" : "/\(combinedPath)"
        components.queryItems = nil

        guard let connectionURL = components.url else {
            throw SynologyError.network(message: "Host not configured")
        }

        return connectionURL
    }

    /// 将参数拼接为 GET URL（含 Query String）
    /// Build GET URL with query parameters
    private func buildUrl(apiUrl: URL, parameters: ApiParameters) throws -> URL {
        guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
            throw SynologyError.network(message: "Host not configured")
        }

        components.queryItems = sortedQueryItems(from: parameters)

        guard let requestUrl = components.url else {
            throw SynologyError.network(message: "Host not configured")
        }

        return requestUrl
    }

    /// 将参数字典排序后转换为 URLQueryItem 列表
    /// Sort and convert parameter dictionary to URLQueryItem list
    ///
    /// `_` 前缀的参数（如 `_sid`）排在普通参数之后，保持 URL 可读性。
    /// Parameters prefixed with `_` (e.g. `_sid`) are placed after regular parameters for readability.
    private func sortedQueryItems(from parameters: ApiParameters) -> [URLQueryItem] {
        parameters.sorted {
            if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
            if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
            return $0.key < $1.key
        }.map { URLQueryItem(name: $0.key, value: $0.value.stringValue) }
    }

    /// 将参数字典编码为 POST body（application/x-www-form-urlencoded）
    /// Encode parameter dictionary as POST body (application/x-www-form-urlencoded)
    private func formURLEncodedBody(parameters: ApiParameters) -> Data? {
        parameters.sorted {
            if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
            if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
            return $0.key < $1.key
        }.map { "\($0.key)=\(UrlUtils.urlEncode($0.value.stringValue))" }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    /// 从参数字典中提取显式 sid/did，构建 Cookie Header（用于脱离拦截器的场景）
    /// Extract explicit sid/did from parameters and build Cookie header (for cases bypassing interceptors)
    private func buildExplicitCookieHeader(parameters: ApiParameters) -> String? {
        if let sid = parameters["sid"]?.stringValue {
            if let did = parameters["did"]?.stringValue {
                return "id=\(sid); did=\(did)"
            }
            return "id=\(sid)"
        }
        return nil
    }

    /// 构建公开 URL 所需的 `_sid` 参数
    /// Build `_sid` parameter for public URL generation
    ///
    /// 仅当端点要求 Query 认证时才注入，否则返回 nil。
    /// Only injects when the endpoint requires query authentication, otherwise returns nil.
    private func buildAmbientAuthQueryParameter(name: String, method: String, requireAuthQuery: Bool) throws -> String? {
        if requireAuthQuery {
            guard let session = sessionProvider() else {
                Logger.error("接口: \(name) \(method) 必须配置 sid 参数，但 session 不存在。")
                throw SynologyError.sessionExpired(code: 0, message: "session invalid, sid not exist")
            }
            return session.sid
        }
        return nil
    }
}
