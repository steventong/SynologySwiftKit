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
struct SynologyResponse<T: Decodable & Sendable>: Decodable, Sendable {
    
    let success: Bool
    let error: SynologyApiError?
    let data: T?

    /// 获取 data，失败时抛出错误
    /// Get data or throw error if failed
    func unwrap() throws -> T {
        if success, let data = data {
            return data
        }

        if let error = error {
            throw error.toSynologyError()
        }

        throw SynologyError.api(code: -1, message: "Unknown error")
    }
}
