//
//  AuthInterceptor.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// 认证拦截器 (初步实现)
///
/// 职责：
/// 1. 为请求注入 SID/DID (Query 或 Cookie)
/// 2. 处理 105/106 等 Token 过期错误 (尚未实现自动重试)
public struct AuthInterceptor: RequestInterceptor {
    // 暂时保留为空结构，实际鉴权逻辑目前仍紧耦合在 ApiClient 中。
    // 在完全解耦前，此拦截器作为占位符，展示架构意图。
    
    public init() {}
    
    public func adapt(_ request: URLRequest, for endpoint: ApiEndpoint) async throws -> URLRequest {
        // TODO: 将 ApiClient 中的鉴权头构建逻辑迁移至此
        return request
    }
}
