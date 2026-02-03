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
    private static let commonErrors: [Int: String] = [
        100: "Unknown error.",
        101: "Invalid parameter.",
        102: "The requested API does not exist.",
        103: "The requested method does not exist.",
        104: "The requested version does not support the functionality.",
        105: "The logged in session does not have permission.",
        106: "Session timeout.",
        107: "Session interrupted by duplicate login.",
        108: "Failed to upload the file.",
        109: "The network connection is unstable or the system is busy.",
        110: "The network connection is unstable or the system is busy.",
        111: "The network connection is unstable or the system is busy.",
        112: "Preserve for other purpose.",
        113: "Preserve for other purpose.",
        114: "Lost parameters for this API.",
        115: "Not allowed to upload a file.",
        116: "Not allowed to perform for a demo site.",
        117: "The network connection is unstable or the system is busy.",
        118: "The network connection is unstable or the system is busy.",
        119: "Invalid session.",
        // 120-149 Preserve for other purpose.
        150: "Request source IP does not match the login IP.",
    ]

    /// 获取错误码对应的描述
    /// Get description for error code
    public static func description(for code: Int) -> String? {
        return commonErrors[code]
    }
}
