import Foundation

struct ApiRequestFactory {
    let connectionProvider: () -> (type: ConnectionType, url: String)?
    let sessionProvider: () -> (sid: String, did: String?)?

    func trustedSSLDomainForCurrentConnection() -> String? {
        guard
            let connection = connectionProvider(),
            connection.type == .custom_domain,
            connection.url.hasPrefix("https://"),
            let url = URL(string: connection.url)
        else {
            return nil
        }
        return url.host
    }

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

    private func sortedQueryItems(from parameters: ApiParameters) -> [URLQueryItem] {
        parameters.sorted {
            if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
            if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
            return $0.key < $1.key
        }.map { URLQueryItem(name: $0.key, value: $0.value.stringValue) }
    }

    private func formURLEncodedBody(parameters: ApiParameters) -> Data? {
        parameters.sorted {
            if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") { return false }
            if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") { return true }
            return $0.key < $1.key
        }.map { "\($0.key)=\(UrlUtils.urlEncode($0.value.stringValue))" }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    private func buildExplicitCookieHeader(parameters: ApiParameters) -> String? {
        if let sid = parameters["sid"]?.stringValue {
            if let did = parameters["did"]?.stringValue {
                return "id=\(sid); did=\(did)"
            }
            return "id=\(sid)"
        }
        return nil
    }

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
