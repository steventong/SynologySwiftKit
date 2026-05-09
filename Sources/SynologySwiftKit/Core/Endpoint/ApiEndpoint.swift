//
//  ApiEndpoint.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiEndpoint

typealias ApiParameters = [String: ApiParameterValue]

enum ApiParameterValue: Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
    case array([ApiParameterValue])

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
        case let .array(values):
            return values.map(\.stringValue).joined(separator: ",")
        }
    }

    static func jsonEncoded<Value: Encodable>(_ value: Value, encoder: JSONEncoder = JSONEncoder()) throws -> ApiParameterValue {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw SynologyError.network(message: "JSON encoding failed")
        }
        return .string(string)
    }
}

extension ApiParameterValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension ApiParameterValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension ApiParameterValue: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension ApiParameterValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension ApiParameterValue: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: ApiParameterValue...) {
        self = .array(elements)
    }
}

extension ApiParameterValue: ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue { self }
}

protocol ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue { get }
}

extension String: ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue { .string(self) }
}

extension Int: ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue { .int(self) }
}

extension Bool: ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue { .bool(self) }
}

extension Double: ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue { .double(self) }
}

extension Float: ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue { .double(Double(self)) }
}

extension Array: ApiParameterValueConvertible where Element: ApiParameterValueConvertible {
    var apiParameterValue: ApiParameterValue {
        .array(map(\.apiParameterValue))
    }
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
struct ApiEndpoint {
    let api: ApiDefinition
    let method: String
    let version: Int
    let httpMethod: HTTPMethod
    let parameters: ApiParameters
    let timeout: TimeInterval
    let pathSuffix: String?
    let fullPath: String?
    let sidOnQuery: Bool?
    let sidOnCookie: Bool?

    /// API 名称
    var apiName: String {
        api.name
    }

    /// 是否需要认证 Cookie
    var requireAuthCookie: Bool {
        api.requiresAuth
    }

    /// 是否需要 Query 中携带 sid
    var requireQuerySid: Bool {
        api.requiresQuerySid
    }

    /// 是否为自定义路径
    var isCustomPath: Bool {
        fullPath != nil
    }

    /// 标准初始化
    /// Standard initialization
    init(api: ApiDefinition, method: String, version: Int = 1, httpMethod: HTTPMethod = .get, parameters: ApiParameters = [:],
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

    /// 自定义路径初始化
    /// Custom path initialization
    init(api: ApiDefinition, fullPath: String, httpMethod: HTTPMethod = .get, parameters: ApiParameters = [:],
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

}

// MARK: - Convenience Factory Methods

extension ApiEndpoint {
    /// 创建 GET 请求端点
    /// Create GET request endpoint
    static func get(api: ApiDefinition, method: String, version: Int = 1, parameters: ApiParameters = [:]) -> ApiEndpoint {
        ApiEndpoint(api: api, method: method, version: version, httpMethod: .get, parameters: parameters)
    }

    /// 创建 POST 请求端点
    /// Create POST request endpoint
    static func post(api: ApiDefinition, method: String, version: Int = 1, parameters: ApiParameters = [:]) -> ApiEndpoint {
        ApiEndpoint(api: api, method: method, version: version, httpMethod: .post, parameters: parameters)
    }

    /// 创建自定义路径端点
    /// Create custom path endpoint
    static func custom(api: ApiDefinition, path: String, httpMethod: HTTPMethod = .post, parameters: ApiParameters = [:]) -> ApiEndpoint {
        ApiEndpoint(api: api, fullPath: path, httpMethod: httpMethod, parameters: parameters)
    }
}

// MARK: - Result Builder Support

extension ApiEndpoint {
    /// 标准初始化 (使用 Result Builder)
    /// Standard initialization with Result Builder
    init(api: ApiDefinition, method: String, version: Int = 1, httpMethod: HTTPMethod = .get,
                timeout: TimeInterval = 10, pathSuffix: String? = nil, sidOnQuery: Bool? = nil, sidOnCookie: Bool? = nil,
                @ApiParametersBuilder parameters: () -> ApiParameters) {
        self.init(api: api, method: method, version: version, httpMethod: httpMethod,
                  parameters: parameters(), timeout: timeout, pathSuffix: pathSuffix,
                  sidOnQuery: sidOnQuery, sidOnCookie: sidOnCookie)
    }

    /// 自定义路径初始化 (使用 Result Builder)
    /// Custom path initialization with Result Builder
    init(api: ApiDefinition, fullPath: String, httpMethod: HTTPMethod = .get, timeout: TimeInterval = 10,
                @ApiParametersBuilder parameters: () -> ApiParameters) {
        self.init(api: api, fullPath: fullPath, httpMethod: httpMethod, parameters: parameters(), timeout: timeout)
    }
}
