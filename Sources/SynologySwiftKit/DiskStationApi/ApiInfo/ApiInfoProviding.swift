//
//  ApiInfoProviding.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiInfoProviding Protocol

/// API 信息提供者协议
/// API information provider protocol
///
/// 定义 API 信息查询和缓存的接口，支持依赖注入模式。
/// Defines interfaces for API information query and caching, supporting dependency injection pattern.
protocol ApiInfoProviding {
    /// 根据 API 名称获取 API 信息
    /// Get API information by API name
    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode

    /// 从 DSM 刷新 API 信息并更新缓存
    func refresh() async throws

    /// 优先从缓存加载 API 信息，不可用时回源刷新
    func loadFromCacheOrRefresh() async throws
}
