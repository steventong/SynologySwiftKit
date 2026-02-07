//
//  HTTPClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

/// 通用 HTTP 客户端
/// A generic HTTP client for making network requests
final class HTTPClient {
    private let session: URLSession

    /// 使用超时配置初始化
    /// Initialize with timeout configuration
    init(timeout: TimeInterval = 10) {
        self.session = URLSessionFactory.createSession(timeoutIntervalForRequest: timeout)
    }

    /// 使用超时和信任的 SSL 域名初始化
    /// Initialize with timeout and trusted SSL domain
    init(timeout: TimeInterval = 10, trustedSSLDomain: String?) {
        self.session = URLSessionFactory.createSession(
            timeoutIntervalForRequest: timeout,
            trustedSSLDomain: trustedSSLDomain
        )
    }

    /// 使用自定义 URLSession 初始化
    /// Initialize with custom URLSession
    init(session: URLSession) {
        self.session = session
    }

    // MARK: - Core Method

    /// 发送原始请求（自动记录日志）
    /// Send raw request (with automatic logging)
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await NetworkLogger.execute(request: request, session: session)
    }

    // MARK: - Convenience Methods

    /// 发送 GET 请求
    func get<T: Decodable>(url: URL, headers: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return try await sendAndDecode(request)
    }

    /// 发送 POST 请求（URL 编码）
    func post<T: Decodable>(url: URL, parameters: [String: Any], headers: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters.urlEncodedData
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return try await sendAndDecode(request)
    }

    /// 发送 POST 请求（JSON 编码）
    func postJSON<T: Decodable, Body: Encodable>(url: URL, body: Body, headers: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return try await sendAndDecode(request)
    }

    /// 检查 URL 是否可达（HTTP 200-299）
    func check(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue

        do {
            let (_, response) = try await send(request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}

// MARK: - Private

private extension HTTPClient {
    /// 发送请求并解码响应
    func sendAndDecode<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await send(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SynologyError.network(.invalidResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SynologyError.network(.httpStatus(code: httpResponse.statusCode))
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SynologyError.network(.decodingFailed(message: error.localizedDescription))
        }
    }
}
