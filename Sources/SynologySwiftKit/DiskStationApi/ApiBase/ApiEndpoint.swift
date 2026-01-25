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

    public let api: ApiDefinition
    public let method: String
    public let version: Int
    public let httpMethod: HTTPMethod
    public let parameters: [String: Any]
    public let timeout: TimeInterval
    public let pathSuffix: String?
    public let fullPath: String?
    public let sidOnQuery: Bool?
    public let sidOnCookie: Bool?

    /// API 名称
    public var apiName: String {
        api.name
    }

    /// 是否需要认证 Cookie
    public var requireAuthCookie: Bool {
        api.requiresAuth
    }

    /// 是否需要 Query 中携带 sid
    public var requireQuerySid: Bool {
        api.requiresQuerySid
    }

    /// 是否为自定义路径
    public var isCustomPath: Bool {
        fullPath != nil
    }

    /// 标准初始化
    /// Standard initialization
    public init(api: ApiDefinition, method: String, version: Int = 1, httpMethod: HTTPMethod = .get,
        parameters: [String: Any] = [:], timeout: TimeInterval = 10, pathSuffix: String? = nil,
        sidOnQuery: Bool? = nil, sidOnCookie: Bool? = nil) {
        self.api = api
        self.method = method
        self.version = version
        self.httpMethod = httpMethod
        self.parameters = parameters
        self.timeout = timeout
        self.pathSuffix = pathSuffix
        self.fullPath = nil
        self.sidOnQuery = sidOnQuery
        self.sidOnCookie = sidOnCookie
    }

    /// 自定义路径初始化
    /// Custom path initialization
    public init(
        api: ApiDefinition, fullPath: String, httpMethod: HTTPMethod = .get,
        parameters: [String: Any] = [:], timeout: TimeInterval = 10
    ) {
        self.api = api
        method = ""
        version = 1
        self.httpMethod = httpMethod
        self.parameters = parameters
        self.timeout = timeout
        pathSuffix = nil
        self.fullPath = fullPath
        sidOnQuery = nil
        sidOnCookie = nil
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
        ApiEndpoint(api: api, fullPath: path, httpMethod: httpMethod, parameters: parameters)
    }
}

// MARK: - Result Builder Support

extension ApiEndpoint {
    /// 标准初始化 (使用 Result Builder)
    /// Standard initialization with Result Builder
    public init(
        api: ApiDefinition, method: String, version: Int = 1, httpMethod: HTTPMethod = .get,
        timeout: TimeInterval = 10, pathSuffix: String? = nil,
        sidOnQuery: Bool? = nil, sidOnCookie: Bool? = nil,
        @ApiParametersBuilder parameters: () -> [String: Any]
    ) {
        self.init(
            api: api, method: method, version: version,
            httpMethod: httpMethod, parameters: parameters(),
            timeout: timeout, pathSuffix: pathSuffix,
            sidOnQuery: sidOnQuery, sidOnCookie: sidOnCookie)
    }

    /// 自定义路径初始化 (使用 Result Builder)
    /// Custom path initialization with Result Builder
    public init(
        api: ApiDefinition, fullPath: String, httpMethod: HTTPMethod = .get,
        timeout: TimeInterval = 10,
        @ApiParametersBuilder parameters: () -> [String: Any]
    ) {
        self.init(
            api: api, fullPath: fullPath, httpMethod: httpMethod, parameters: parameters(),
            timeout: timeout)
    }
}
