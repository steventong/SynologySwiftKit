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
        100: "未知错误 (Unknown error)",
        101: "无效的参数 (Invalid parameter)",
        102: "请求的 API 不存在 (The requested API does not exist)",
        103: "请求的方法不存在 (The requested method does not exist)",
        104: "请求的版本不支持该功能 (The requested version does not support the functionality)",
        105: "登录的会话没有权限 (The logged in session does not have permission)",
        106: "会话超时 (Session timeout)",
        107: "会话因重复登录而中断 (Session interrupted by duplicate login)",

        // 认证相关常见错误 (AudioStation 等可能复用)
        400: "无效的用户/密码或账户被禁用 (Invalid user/password or account disabled)",
        401: "账户被禁用 (Account disabled)",
        402: "权限不足 (Permission denied)",
        403: "两步验证代码错误 (2-step verification code error)",
        404: "两步验证代码过期 (2-step verification code expired)",
    ]

    /// 获取错误码对应的描述
    /// Get description for error code
    public static func description(for code: Int) -> String? {
        return commonErrors[code]
    }
}
