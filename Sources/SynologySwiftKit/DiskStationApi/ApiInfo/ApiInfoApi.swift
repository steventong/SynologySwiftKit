//
//  ApiInfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiInfoApi

/// API 信息管理类
/// API information manager
final class ApiInfoApi: ApiInfoProviding {
    // MARK: - Dependencies & State

    /// API 客户端
    private let apiClient: ApiRequestSending

    /// 键值存储 (用于持久化缓存)
    private let keyValueStorage: KeyValueStorage

    private let cache = ApiInfoCache()

    /// API 缓存有效期 (秒)
    private let cacheValidity: Int32

    // MARK: - Initialization

    /// 初始化 API 信息管理器
    /// Initialize API information manager
    init(apiClient: ApiRequestSending,
                keyValueStorage: KeyValueStorage = StorageService(),
                cacheValidity: Int32 = SynologyConfig.default.apiInfoCacheValidity) {
        self.apiClient = apiClient
        self.keyValueStorage = keyValueStorage
        self.cacheValidity = cacheValidity
    }

    /// 根据 API 名称获取 API 节点信息
    /// Get API node info by API name
    /// - Note: `SYNO.API.Info` 终端节点直接返回硬编码路径，不查询远端 / `SYNO.API.Info` returns a hardcoded path without querying remote
    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
        if apiName == SynologyApi.Core.INFO.name {
            return ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil)
        }

        if cache.isEmpty, let cached = getApiInfoFromStorage() {
            cache.replace(with: cached)
            Logger.debug("ApiInfoApi#getApiInfoByApiName load from cache: \(cached.count)")
        }

        guard let apiInfo = cache.node(for: apiName) else {
            Logger.warn("ApiInfoApi#getApiInfoByApiName api not found: \(apiName)")
            throw SynologyError.api(code: 102, message: "API not found: \(apiName)")
        }

        return apiInfo
    }

    /// 优先从缓存加载，缓存过期或不存在时回源刷新
    /// Load from cache first; refresh from remote if cache is expired or unavailable
    func loadFromCacheOrRefresh() async throws {
        if isApiInfoCacheValid(validTime: cacheValidity), let cached = getApiInfoFromStorage() {
            Logger.debug("ApiInfoApi#loadFromCacheOrRefresh from cache: \(cached.count)")
            cache.replace(with: cached)
            return
        }

        try await refresh()
    }

    /// 从 DSM 刷新 API 信息列表并更新内存/持久化缓存
    /// Refresh API info list from DSM and update memory/persistent cache
    func refresh() async throws {
        let apiInfo = try await queryApiInfoFromDsm()
        cache.replace(with: apiInfo)
        Logger.debug("ApiInfoApi#refresh from api: \(apiInfo.count)")

        if apiInfo.isEmpty == false {
            keyValueStorage.setCodable(apiInfo, forKey: KeyValueStorageKeys.DISK_STATION_API_INFO.keyName)
            keyValueStorage.setDate(Date(), forKey: KeyValueStorageKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName)
        }
    }
}

extension ApiInfoApi {
    /// 向 DSM 发起 `SYNO.API.Info query` 请求，获取全量 API 信息
    /// Send `SYNO.API.Info query` request to DSM to get all API info
    private func queryApiInfoFromDsm() async throws -> [String: ApiInfoNode] {
        let api = ApiEndpoint(api: SynologyApi.Core.INFO, method: "query") {
            ("query", "all")
        }
        let apiInfo: [String: ApiInfoNode] = try await apiClient.request(api)
        return apiInfo
    }

    /// 从 UserDefaults 读取持久化的 API 信息字典
    /// Read persisted API info dictionary from UserDefaults
    private func getApiInfoFromStorage() -> [String: ApiInfoNode]? {
        if let apiInfo: [String: ApiInfoNode] = keyValueStorage.codable(forKey: KeyValueStorageKeys.DISK_STATION_API_INFO.keyName) {
            return apiInfo
        }

        return nil
    }

    /// 检查 API 信息缓存是否在有效期内
    /// Check whether the API info cache is within its validity period
    private func isApiInfoCacheValid(validTime: Int32?) -> Bool {
        if let lastUpdateTime = keyValueStorage.date(forKey: KeyValueStorageKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName) {
            return Int32(Date().timeIntervalSince(lastUpdateTime)) < (validTime ?? 24 * 60 * 60)
        }
        return false
    }
}

/// 线程安全的 API 信息内存缓存
/// Thread-safe in-memory cache for API info
private final class ApiInfoCache {
    private let lock = NSLock()
    private var nodes: [String: ApiInfoNode] = [:]

    /// 缓存是否为空 / Whether the cache is empty
    var isEmpty: Bool {
        lock.withLock { nodes.isEmpty }
    }

    /// 根据 API 名称获取节点 / Get node by API name
    func node(for apiName: String) -> ApiInfoNode? {
        lock.withLock { nodes[apiName] }
    }

    /// 替换所有缓存节点 / Replace all cached nodes
    func replace(with nodes: [String: ApiInfoNode]) {
        lock.withLock {
            self.nodes = nodes
        }
    }
}

private extension NSLock {
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
