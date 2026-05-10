//
//  ApiInfoModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiInfoNode

/// DSM API 描述节点
/// DSM API descriptor node
///
/// 由 `SYNO.API.Info query` 接口返回，描述某个具体 API 的路径和版本范围。
/// Returned by `SYNO.API.Info query`; describes the path and version range of a specific API.
public struct ApiInfoNode: Codable, Sendable {
    /// API 的 CGI 路径（如 "entry.cgi" 或 "auth.cgi"）
    /// API CGI path (e.g. "entry.cgi" or "auth.cgi")
    public let path: String

    /// 服务器支持的最低版本号
    /// Minimum version supported by the server
    public let minVersion: Int

    /// 服务器支持的最高版本号
    /// Maximum version supported by the server
    public let maxVersion: Int

    /// 请求格式（可选，如 "JSON"）
    /// Request format (optional, e.g. "JSON")
    public let requestFormat: String?
}
