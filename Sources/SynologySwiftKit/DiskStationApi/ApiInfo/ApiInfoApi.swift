//
//  ApiInfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiInfoApi

/// API 信息管理类 (Actor 保证并发安全)
/// API information manager (Actor ensures concurrency safety)
actor ApiInfoApi: ApiInfoProviding {
    // MARK: - Dependencies & State

    /// API 客户端
    private let apiClient: ApiRequestSending

    /// 键值存储 (用于持久化缓存)
    private let keyValueStorage: KeyValueStorage

    /// 缓存的 API 信息
    private var cachedApiInfo: [String: ApiInfoNode] = [:]

    /// API 缓存有效期 (秒)
    private let cacheValidity: Int32

    // MARK: - Initialization

    /// 初始化 API 信息管理器
    /// Initialize API information manager
    init(apiClient: ApiRequestSending,
                keyValueStorage: KeyValueStorage = UserDefaultsStorage(),
                cacheValidity: Int32 = SynologyConfig.default.apiInfoCacheValidity) {
        self.apiClient = apiClient
        self.keyValueStorage = keyValueStorage
        self.cacheValidity = cacheValidity
    }

    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
        if apiName == SynologyApi.Core.INFO.name {
            return ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil)
        }

        if cachedApiInfo.isEmpty, let cached = getApiInfoFromStorage() {
            cachedApiInfo = cached
            Logger.debug("ApiInfoApi#getApiInfoByApiName load from cache: \(cached.count)")
        }

        guard let apiInfo = cachedApiInfo[apiName] else {
            Logger.info("ApiInfoApi#getApiInfoByApiName (\(apiName)) not exist")
            throw SynologyError.api(code: 102, message: "API not found: \(apiName)")
        }

        Logger.debug("ApiInfoApi#getApiInfoByApiName get apiInfo, key: \(apiName), value = \(apiInfo)")
        return apiInfo
    }

    func loadFromCacheOrRefresh() async throws {
        if isApiInfoCacheValid(validTime: cacheValidity), let cached = getApiInfoFromStorage() {
            Logger.debug("ApiInfoApi#loadFromCacheOrRefresh from cache: \(cached.count)")
            cachedApiInfo = cached
            return
        }

        try await refresh()
    }

    func refresh() async throws {
        cachedApiInfo = try await queryApiInfoFromDsm()
        Logger.debug("ApiInfoApi#refresh from api: \(cachedApiInfo.count)")

        if cachedApiInfo.isEmpty == false {
            keyValueStorage.setCodable(cachedApiInfo, forKey: KeyValueStorageKeys.DISK_STATION_API_INFO.keyName)
            keyValueStorage.setDate(Date(), forKey: KeyValueStorageKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName)
        }
    }
}

extension ApiInfoApi {
    private func queryApiInfoFromDsm() async throws -> [String: ApiInfoNode] {
        let api = ApiEndpoint(api: SynologyApi.Core.INFO, method: "query") {
            ("query", "all")
        }
        let apiInfo: [String: ApiInfoNode] = try await apiClient.request(api)
        return apiInfo
    }

    private func getApiInfoFromStorage() -> [String: ApiInfoNode]? {
        if let apiInfo: [String: ApiInfoNode] = keyValueStorage.codable(forKey: KeyValueStorageKeys.DISK_STATION_API_INFO.keyName) {
            return apiInfo
        }

        return nil
    }

    private func isApiInfoCacheValid(validTime: Int32?) -> Bool {
        if let lastUpdateTime = keyValueStorage.date(forKey: KeyValueStorageKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName) {
            return Int32(Date().timeIntervalSince(lastUpdateTime)) < (validTime ?? 24 * 60 * 60)
        }
        return false
    }
}
