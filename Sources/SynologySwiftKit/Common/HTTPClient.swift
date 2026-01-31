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
    
    /// 使用默认配置初始化
    init(timeout: TimeInterval = 10) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: configuration)
    }
    
    /// 使用配置初始化
    init(config: SynologyConfig) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeoutInterval
        self.session = URLSession(configuration: configuration)
    }
    
    /// 使用自定义 URLSession 初始化
    init(session: URLSession) {
        self.session = session
    }
    
    /// 发送 GET 请求
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - headers: 可选的请求头
    /// - Returns: 解码后的响应数据
    func get<T: Decodable>(url: URL, headers: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        return try await sendRequest(request)
    }
    
    /// 发送 POST 请求（URL 编码）
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - parameters: 请求参数
    ///   - headers: 可选的请求头
    /// - Returns: 解码后的响应数据
    func post<T: Decodable>(url: URL, parameters: [String: Any], headers: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters.urlEncodedData
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        return try await sendRequest(request)
    }
    
    /// 发送 POST 请求（JSON 编码）
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - body: 请求体（Encodable）
    ///   - headers: 可选的请求头
    /// - Returns: 解码后的响应数据
    func postJSON<T: Decodable, Body: Encodable>(url: URL, body: Body, headers: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        return try await sendRequest(request)
    }
    
    /// 发送请求（无返回值解码，仅检查是否成功）
    /// - Parameter url: 请求 URL
    /// - Returns: 是否成功（HTTP 200-299）
    func check(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        
        do {
            let startTime = Date()
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            NetworkLogger.logResponse(url: url, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields, data: data, duration: duration)
            
            return httpResponse.statusCode >= 200 && httpResponse.statusCode < 300
        } catch {
            NetworkLogger.logError(url: url, error: error, duration: 0)
            return false
        }
    }
}

// MARK: - Private

extension HTTPClient {
    /// 发送请求并解码响应
    private func sendRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let url = request.url ?? URL(string: "unknown")!
        
        // 记录请求日志
        NetworkLogger.logRequest(
            url: url,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields,
            body: request.httpBody
        )
        
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SynologyError.NetworkError.invalidResponse
            }
            
            // 记录响应日志
            NetworkLogger.logResponse(
                url: url,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields,
                data: data,
                duration: duration
            )
            
            // 检查 HTTP 状态码
            guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                throw SynologyError.NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // 解码响应
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw SynologyError.NetworkError.decodingError(error)
            }
        } catch let error as SynologyError.NetworkError {
            let duration = Date().timeIntervalSince(startTime)
            NetworkLogger.logError(url: url, error: error, duration: duration)
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            NetworkLogger.logError(url: url, error: error, duration: duration)
            throw SynologyError.NetworkError.connectionFailed(underlying: error)
        }
    }
}
