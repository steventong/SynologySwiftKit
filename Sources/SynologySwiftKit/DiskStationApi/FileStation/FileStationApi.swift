//
//  FileStationApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/4.
//

import Foundation

/// FileStation API 入口（依赖注入）
/// FileStation API entry (dependency injection)
public class FileStationApi {

    /// API 客户端（internal 以便 extension 使用）
    /// API client (internal for extension access)
    let apiClient: ApiClientProviding

    /// 初始化 FileStation API
    /// Initialize FileStation API
    /// - Parameter apiClient: API 客户端
    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }
}
