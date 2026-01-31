//
//  SynologyApiResponse.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - Synology API Response

/// Synology API 通用响应结构
/// Generic response structure for all Synology APIs
///
/// Synology API 返回格式一致：
/// ```json
/// // 成功：{ "success": true, "data": { ... } }
/// // 失败：{ "success": false, "error": { "code": 1002, "errors": [1006] } }
/// ```
public struct SynologyResponse<T: Decodable>: Decodable {
    
    public let success: Bool
    public let error: SynologyApiError?
    public let data: T?

    /// 获取 data，失败时抛出错误
    /// Get data or throw error if failed
    public func unwrap() throws -> T {
        if success, let data = data {
            return data
        }

        if let error = error {
            throw error
        }

        throw SynologyApiError.unknown
    }
}

// MARK: - Synology Error

/// Synology API 错误
/// 同时支持 JSON 解码和 Error 协议
public struct SynologyApiError: Error, Decodable, LocalizedError, CustomStringConvertible {
    /// 主错误码
    public let code: Int
    /// 子错误码列表
    public let errors: [Int]

    /// 未知错误
    public static let unknown = SynologyApiError(code: -1, errors: [])

    // MARK: - Decodable

    enum CodingKeys: String, CodingKey {
        case code
        case errors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        errors = try container.decodeIfPresent([Int].self, forKey: .errors) ?? []
    }

    public init(code: Int, errors: [Int] = []) {
        self.code = code
        self.errors = errors
    }

    // MARK: - Convenience

    /// 第一个错误码（优先返回 errors 中的第一个，否则返回主 code）
    public var primaryCode: Int {
        errors.first ?? code
    }

    /// 是否匹配指定错误码
    public func hasError(_ errorCode: Int) -> Bool {
        code == errorCode || errors.contains(errorCode)
    }

    // MARK: - Error Protocol

    public var errorDescription: String? {
        "Synology API Error (code: \(code), errors: \(errors))"
    }

    public var description: String {
        "SynologyError(code: \(code), errors: \(errors))"
    }
}

// MARK: - Synology List Result

/// 通用列表响应结构
/// Generic list response structure
public struct SynologyListResult<T: Decodable & Sendable>: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let items: [T]
}

