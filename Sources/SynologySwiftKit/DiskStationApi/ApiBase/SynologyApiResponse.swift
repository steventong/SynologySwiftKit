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
    public let data: T?
    public let error: SynologyErrorInfo?
    
    /// 获取 data，失败时抛出错误
    /// Get data or throw error if failed
    public func unwrap() throws -> T {
        if success, let data = data {
            return data
        }
        if let error = error {
            throw SynologyError(code: error.code, errors: error.errors ?? [])
        }
        throw SynologyError.unknown
    }
    
    /// 获取可选 data，失败时抛出错误
    public func unwrapOptional() throws -> T? {
        if success {
            return data
        }
        if let error = error {
            throw SynologyError(code: error.code, errors: error.errors ?? [])
        }
        throw SynologyError.unknown
    }
}

/// Synology 错误信息
public struct SynologyErrorInfo: Decodable {
    public let code: Int
    public let errors: [Int]?
}

// MARK: - Synology Error

/// Synology API 错误
public struct SynologyError: Error, LocalizedError, CustomStringConvertible {
    /// 主错误码
    public let code: Int
    /// 子错误码列表
    public let errors: [Int]
    
    /// 未知错误
    public static let unknown = SynologyError(code: -1, errors: [])
    
    /// 第一个错误码（优先返回 errors 中的第一个，否则返回主 code）
    public var primaryCode: Int {
        errors.first ?? code
    }
    
    /// 是否匹配指定错误码
    public func hasError(_ errorCode: Int) -> Bool {
        code == errorCode || errors.contains(errorCode)
    }
    
    public var errorDescription: String? {
        "Synology API Error (code: \(code), errors: \(errors))"
    }
    
    public var description: String {
        "SynologyError(code: \(code), errors: \(errors))"
    }
}

// MARK: - DiskStationApi Extension

extension DiskStationApi {
    
    /// 请求并自动解析响应，失败时抛出 SynologyError
    /// Request and parse response, throw SynologyError on failure
    ///
    /// 使用示例：
    /// ```swift
    /// let result: PinOperationResult = try await api.fetch()
    /// ```
    public func fetch<T: Decodable>() async throws -> T {
        let response = try await requestForResult(resultType: SynologyResponse<T>.self)
        return try response.unwrap()
    }
    
    /// 请求并自动解析响应（可选返回），失败时抛出 SynologyError
    public func fetchOptional<T: Decodable>() async throws -> T? {
        let response = try await requestForResult(resultType: SynologyResponse<T>.self)
        return try response.unwrapOptional()
    }
}
