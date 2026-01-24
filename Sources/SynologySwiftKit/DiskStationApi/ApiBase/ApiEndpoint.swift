//
//  ApiEndpoint.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiEndpoint

/// API 端点（纯数据结构，描述一个 API 请求）
/// API endpoint (pure data structure describing an API request)
///
/// 使用示例 / Usage example:
/// ```swift
/// let result: PinListResult = try await apiClient.request(
///     ApiEndpoint(api: SynologyApi.AudioStation.pin, method: "list", parameters: ["limit": 10])
/// )
/// ```
public struct ApiEndpoint {
    public let apiDefinition: ApiDefinition
    public let method: String
    public let version: Int
    public let httpMethod: HTTPMethod
    public let parameters: [String: Any]
    public let timeout: TimeInterval
    public let path: String?
    public let customPath: String?
    public let sidOnQuery: Bool?
    public let sidOnCookie: Bool?

    /// API 名称
    public var apiName: String {
        apiDefinition.name
    }

    /// 是否需要认证 Cookie
    public var requireAuthCookie: Bool {
        apiDefinition.requiresAuth
    }

    /// 是否需要 Query 中携带 sid
    public var requireQuerySid: Bool {
        apiDefinition.requiresQuerySid
    }

    /// 是否为自定义路径
    public var isCustomPath: Bool {
        customPath != nil
    }

    /// 标准初始化
    /// Standard initialization
    public init(
        api: ApiDefinition,
        method: String,
        version: Int = 1,
        httpMethod: HTTPMethod = .get,
        parameters: [String: Any] = [:],
        timeout: TimeInterval = 10,
        path: String? = nil,
        sidOnQuery: Bool? = nil,
        sidOnCookie: Bool? = nil
    ) {
        self.apiDefinition = api
        self.method = method
        self.version = version
        self.httpMethod = httpMethod
        self.parameters = parameters
        self.timeout = timeout
        self.path = path
        self.customPath = nil
        self.sidOnQuery = sidOnQuery
        self.sidOnCookie = sidOnCookie
    }

    /// 自定义路径初始化
    /// Custom path initialization
    public init(
        api: ApiDefinition,
        customPath: String,
        httpMethod: HTTPMethod = .get,
        parameters: [String: Any] = [:],
        timeout: TimeInterval = 10
    ) {
        self.apiDefinition = api
        self.method = ""
        self.version = 1
        self.httpMethod = httpMethod
        self.parameters = parameters
        self.timeout = timeout
        self.path = nil
        self.customPath = customPath
        self.sidOnQuery = nil
        self.sidOnCookie = nil
    }
}

// MARK: - Convenience Factory Methods

extension ApiEndpoint {
    /// 创建 GET 请求端点
    /// Create GET request endpoint
    public static func get(
        api: ApiDefinition,
        method: String,
        version: Int = 1,
        parameters: [String: Any] = [:]
    ) -> ApiEndpoint {
        ApiEndpoint(
            api: api, method: method, version: version, httpMethod: .get, parameters: parameters)
    }

    /// 创建 POST 请求端点
    /// Create POST request endpoint
    public static func post(
        api: ApiDefinition,
        method: String,
        version: Int = 1,
        parameters: [String: Any] = [:]
    ) -> ApiEndpoint {
        ApiEndpoint(
            api: api, method: method, version: version, httpMethod: .post, parameters: parameters)
    }

    /// 创建自定义路径端点
    /// Create custom path endpoint
    public static func custom(
        api: ApiDefinition,
        path: String,
        httpMethod: HTTPMethod = .post,
        parameters: [String: Any] = [:]
    ) -> ApiEndpoint {
        ApiEndpoint(api: api, customPath: path, httpMethod: httpMethod, parameters: parameters)
    }
}
