//
//  SynologyErrorMapper.swift
//  SynologySwiftKit
//
//  Created by SynologySwiftKit on 2026/01/25.
//

import Foundation

/// Synology API 错误码映射
/// Synology API Error Code Mapper
public struct SynologyErrorMapper {
    
    /// 通用错误码映射表
    /// Common error code mapping table
    private static let commonErrors: [Int: String] = [:]

    /// 获取错误码对应的描述
    /// Get description for error code
    public static func description(for code: Int) -> String? {
        return commonErrors[code]
    }
}
