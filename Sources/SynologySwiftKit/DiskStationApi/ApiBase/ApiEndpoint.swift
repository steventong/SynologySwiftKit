//
//  ApiEndpoint.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiEndpoint

public typealias ApiParameters = [String: ApiParameterValue]

public enum ApiParameterValue: Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)

    var stringValue: String {
        switch self {
        case let .string(value):
            return value
        case let .int(value):
            return String(value)
        case let .bool(value):
            return value ? "true" : "false"
        case let .double(value):
            return String(value)
        }
    }

    static func from(_ value: Any) -> ApiParameterValue {
        switch value {
        case let v as String:
            return .string(v)
        case let v as Int:
            return .int(v)
        case let v as Bool:
            return .bool(v)
        case let v as Double:
            return .double(v)
        case let v as Float:
            return .double(Double(v))
        default:
            return .string(String(describing: value))
        }
    }
}

extension ApiParameterValue: ApiParameterValueConvertible {
    public var apiParameterValue: ApiParameterValue { self }
}

public protocol ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue { get }
}

extension String: ApiParameterValueConvertible {
    public var apiParameterValue: ApiParameterValue { .string(self) }
}

extension Int: ApiParameterValueConvertible {
    public var apiParameterValue: ApiParameterValue { .int(self) }
}

extension Bool: ApiParameterValueConvertible {
    public var apiParameterValue: ApiParameterValue { .bool(self) }
}

extension Double: ApiParameterValueConvertible {
    public var apiParameterValue: ApiParameterValue { .double(self) }
}

extension Float: ApiParameterValueConvertible {
    public var apiParameterValue: ApiParameterValue { .double(Double(self)) }
}

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
    public let parameters: ApiParameters
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
    public init(api: ApiDefinition, method: String, version: Int = 1, httpMethod: HTTPMethod = .get, parameters: ApiParameters = [:],
                timeout: TimeInterval = 10, pathSuffix: String? = nil, sidOnQuery: Bool? = nil, sidOnCookie: Bool? = nil) {
        self.api = api
        self.method = method
        self.version = version
        self.httpMethod = httpMethod
        self.parameters = parameters
        self.timeout = timeout
        self.pathSuffix = pathSuffix
        fullPath = nil
        self.sidOnQuery = sidOnQuery
        self.sidOnCookie = sidOnCookie
    }

    /// 标准初始化（兼容 Any 参数）
    /// Standard initialization (compatible with Any parameters)
    public init(api: ApiDefinition, method: String, version: Int = 1, httpMethod: HTTPMethod = .get, parameters: [String: Any],
                timeout: TimeInterval = 10, pathSuffix: String? = nil, sidOnQuery: Bool? = nil, sidOnCookie: Bool? = nil) {
        let converted = parameters.mapValues { ApiParameterValue.from($0) }
        self.init(api: api, method: method, version: version, httpMethod: httpMethod, parameters: converted,
                  timeout: timeout, pathSuffix: pathSuffix, sidOnQuery: sidOnQuery, sidOnCookie: sidOnCookie)
    }

    /// 自定义路径初始化
    /// Custom path initialization
    public init(api: ApiDefinition, fullPath: String, httpMethod: HTTPMethod = .get, parameters: ApiParameters = [:],
                timeout: TimeInterval = 10) {
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

    /// 自定义路径初始化（兼容 Any 参数）
    /// Custom path initialization (compatible with Any parameters)
    public init(api: ApiDefinition, fullPath: String, httpMethod: HTTPMethod = .get, parameters: [String: Any],
                timeout: TimeInterval = 10) {
        let converted = parameters.mapValues { ApiParameterValue.from($0) }
        self.init(api: api, fullPath: fullPath, httpMethod: httpMethod, parameters: converted, timeout: timeout)
    }
}

// MARK: - Convenience Factory Methods

extension ApiEndpoint {
    /// 创建 GET 请求端点
    /// Create GET request endpoint
    public static func get(api: ApiDefinition, method: String, version: Int = 1, parameters: ApiParameters = [:]) -> ApiEndpoint {
        ApiEndpoint(api: api, method: method, version: version, httpMethod: .get, parameters: parameters)
    }

    /// 创建 POST 请求端点
    /// Create POST request endpoint
    public static func post(api: ApiDefinition, method: String, version: Int = 1, parameters: ApiParameters = [:]) -> ApiEndpoint {
        ApiEndpoint(api: api, method: method, version: version, httpMethod: .post, parameters: parameters)
    }

    /// 创建自定义路径端点
    /// Create custom path endpoint
    public static func custom(api: ApiDefinition, path: String, httpMethod: HTTPMethod = .post, parameters: ApiParameters = [:]) -> ApiEndpoint {
        ApiEndpoint(api: api, fullPath: path, httpMethod: httpMethod, parameters: parameters)
    }
}

// MARK: - Result Builder Support

extension ApiEndpoint {
    /// 标准初始化 (使用 Result Builder)
    /// Standard initialization with Result Builder
    public init(api: ApiDefinition, method: String, version: Int = 1, httpMethod: HTTPMethod = .get,
                timeout: TimeInterval = 10, pathSuffix: String? = nil, sidOnQuery: Bool? = nil, sidOnCookie: Bool? = nil,
                @ApiParametersBuilder parameters: () -> ApiParameters) {
        self.init(api: api, method: method, version: version, httpMethod: httpMethod,
                  parameters: parameters(), timeout: timeout, pathSuffix: pathSuffix,
                  sidOnQuery: sidOnQuery, sidOnCookie: sidOnCookie)
    }

    /// 自定义路径初始化 (使用 Result Builder)
    /// Custom path initialization with Result Builder
    public init(api: ApiDefinition, fullPath: String, httpMethod: HTTPMethod = .get, timeout: TimeInterval = 10,
                @ApiParametersBuilder parameters: () -> ApiParameters) {
        self.init(api: api, fullPath: fullPath, httpMethod: httpMethod, parameters: parameters(), timeout: timeout)
    }
}
