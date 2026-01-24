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
///     ApiEndpoint(api: .SYNO_AUDIO_STATION_PIN, method: "list", parameters: ["limit": 10])
/// )
/// ```
public struct ApiEndpoint {
    public let api: DiskStationApiDefine
    public let method: String
    public let version: Int
    public let httpMethod: HTTPMethod
    public let parameters: [String: Any]
    public let timeout: TimeInterval
    public let path: String?
    public let sidOnQuery: Bool?
    public let sidOnCookie: Bool?
    public let isCustomPath: Bool

    /// 标准 API 初始化
    /// Standard API initialization
    public init(
        api: DiskStationApiDefine,
        method: String,
        version: Int = 1,
        httpMethod: HTTPMethod = .get,
        parameters: [String: Any] = [:],
        timeout: TimeInterval = 10,
        path: String? = nil,
        sidOnQuery: Bool? = nil,
        sidOnCookie: Bool? = nil
    ) {
        self.api = api
        self.method = method
        self.version = version
        self.httpMethod = httpMethod
        self.parameters = parameters
        self.timeout = timeout
        self.path = path
        self.sidOnQuery = sidOnQuery
        self.sidOnCookie = sidOnCookie
        self.isCustomPath = false
    }

    /// 自定义路径初始化
    /// Custom path initialization
    init(
        api: DiskStationApiDefine,
        customPath: String,
        httpMethod: HTTPMethod = .get,
        parameters: [String: Any] = [:],
        timeout: TimeInterval = 10
    ) {
        self.api = api
        self.method = ""
        self.version = 1
        self.httpMethod = httpMethod
        self.parameters = parameters
        self.timeout = timeout
        self.path = customPath
        self.sidOnQuery = nil
        self.sidOnCookie = nil
        self.isCustomPath = true
    }
}

// MARK: - Convenience Factory Methods

extension ApiEndpoint {
    /// 创建 GET 请求端点
    /// Create GET request endpoint
    static func get(
        api: DiskStationApiDefine,
        method: String,
        version: Int = 1,
        parameters: [String: Any] = [:]
    ) -> ApiEndpoint {
        ApiEndpoint(
            api: api, method: method, version: version, httpMethod: .get, parameters: parameters)
    }

    /// 创建 POST 请求端点
    /// Create POST request endpoint
    static func post(
        api: DiskStationApiDefine,
        method: String,
        version: Int = 1,
        parameters: [String: Any] = [:]
    ) -> ApiEndpoint {
        ApiEndpoint(
            api: api, method: method, version: version, httpMethod: .post, parameters: parameters)
    }

    /// 创建自定义路径端点
    /// Create custom path endpoint
    static func custom(
        api: DiskStationApiDefine,
        path: String,
        httpMethod: HTTPMethod = .post,
        parameters: [String: Any] = [:]
    ) -> ApiEndpoint {
        ApiEndpoint(api: api, customPath: path, httpMethod: httpMethod, parameters: parameters)
    }
}
