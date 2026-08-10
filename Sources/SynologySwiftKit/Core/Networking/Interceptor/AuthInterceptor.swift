//
//  AuthInterceptor.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation
import SwiftHttpClient

/// 认证拦截器
///
/// 职责：
/// 1. 为运行时请求注入当前会话的 SID/DID (Query 或 Cookie)
/// 2. 处理 106/107/119 等会话过期错误
///
/// 说明：
/// - 常规 API 请求的鉴权统一由该拦截器负责。
/// - `ApiRequestFactory.buildUrl` 仍会为公开 URL 生成场景补 `_sid`。
struct AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    private let sessionProvider: (() -> (sid: String, did: String?)?)?
    private let onSessionExpired: (() -> Void)?

    init() {
        sessionProvider = nil
        onSessionExpired = nil
    }

    init(sessionProvider: @escaping () -> (sid: String, did: String?)?, onSessionExpired: (() -> Void)? = nil) {
        self.sessionProvider = sessionProvider
        self.onSessionExpired = onSessionExpired
    }

    func adapt(_ request: URLRequest, for endpoint: ApiEndpoint) async throws -> URLRequest {
        var updatedRequest = request

        // 需要在query请求参数中添加sid参数。
        if needsQuerySid(for: endpoint) {
            guard let sid = sessionProvider?()?.sid, !sid.isEmpty else {
                throw SynologyError.sessionExpired(code: 0, message: "session invalid, sid not exist")
            }
            updatedRequest = injectQuerySidIfNeeded(sid, into: updatedRequest)
        }

        // 需要在http header cookie 请求中添加sid/did参数
        if needsAuthCookie(for: endpoint) {
            guard let session = sessionProvider?(), !session.sid.isEmpty else {
                throw SynologyError.sessionExpired(code: 0, message: "session invalid, sid not exist")
            }
            updatedRequest = injectCookieIfNeeded(sid: session.sid, did: session.did, into: updatedRequest)
        }

        return updatedRequest
    }

    func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint) async throws -> Result<(Data, URLResponse), Error> {
        if case let .failure(error) = result, isSessionExpiredError(error) {
            let session = sessionProvider?()
            Logger.warn(
                "AuthInterceptor#process detected invalid session, api=\(endpoint.apiName), method=\(endpoint.method), error=\(error), \(Logger.sessionSummary(sid: session?.sid, did: session?.did))"
            )
            onSessionExpired?()
        }
        return result
    }

    private func needsQuerySid(for endpoint: ApiEndpoint) -> Bool {
        endpoint.sidOnQuery ?? endpoint.requireQuerySid
    }

    private func needsAuthCookie(for endpoint: ApiEndpoint) -> Bool {
        endpoint.sidOnCookie ?? endpoint.requireAuthCookie
    }

    private func isSessionExpiredError(_ error: Error) -> Bool {
        guard let synologyError = error as? SynologyError else {
            return false
        }
        guard case let .sessionExpired(code, _) = synologyError else {
            return false
        }
        return code == 0 || [106, 107, 119].contains(code)
    }
}

extension AuthInterceptor {
    /// 按需将 `_sid` 注入到请求的 Query 参数中
    /// Inject `_sid` into the request's query parameters if needed
    ///
    /// - GET 请求：注入到 URL Query String
    ///   GET request: inject into URL query string
    /// - POST/PUT/DELETE 请求：注入到 Body 中
    ///   POST/PUT/DELETE request: inject into request body
    /// - 已存在 `_sid` 时不重复注入 / Skips injection if `_sid` already present
    private func injectQuerySidIfNeeded(_ sid: String, into request: URLRequest) -> URLRequest {
        var updatedRequest = request
        let method = HTTPMethod(rawValue: request.httpMethod ?? "GET") ?? .get

        switch method {
        case .get:
            guard let url = request.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return request
            }

            var queryItems = components.queryItems ?? []
            if queryItems.contains(where: { $0.name == "_sid" }) {
                return request
            }
            queryItems.append(URLQueryItem(name: "_sid", value: sid))
            components.queryItems = queryItems
            updatedRequest.url = components.url
        case .post, .put, .delete:
            let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            let hasSid = bodyString
                .split(separator: "&")
                .contains { $0.split(separator: "=", maxSplits: 1).first == "_sid" }
            if hasSid {
                return request
            }

            let sidPair = "_sid=\(URLCoding.encode(sid))"
            let updatedBodyString = bodyString.isEmpty ? sidPair : "\(bodyString)&\(sidPair)"
            updatedRequest.httpBody = updatedBodyString.data(using: .utf8)
        }

        return updatedRequest
    }

    /// 按需将 SID/DID 注入到 Cookie Header 中
    /// Inject SID/DID into the Cookie header if needed
    ///
    /// Cookie 格式：`id=<sid>; did=<did>`（did 可选）
    /// Cookie format: `id=<sid>; did=<did>` (did is optional)
    /// - 已包含 `id=` 时不重复注入 / Skips injection if `id=` already present in Cookie
    private func injectCookieIfNeeded(sid: String, did: String?, into request: URLRequest) -> URLRequest {
        var updatedRequest = request
        let existingCookie = request.value(forHTTPHeaderField: "Cookie") ?? ""

        if existingCookie.contains("id=") {
            return request
        }

        var cookie = "id=\(sid)"
        if let did, !did.isEmpty {
            cookie += "; did=\(did)"
        }

        let mergedCookie = existingCookie.isEmpty ? cookie : "\(existingCookie); \(cookie)"
        updatedRequest.setValue(mergedCookie, forHTTPHeaderField: "Cookie")
        return updatedRequest
    }
}
