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
public actor ApiInfoApi: ApiInfoProviding {
    // MARK: - Dependencies & State

    /// API 客户端
    private let apiClient: ApiClientProviding

    /// 键值存储 (用于持久化缓存)
    private let storage: KeyValueStorage

    /// 缓存的 API 信息
    private var cachedApiInfo: [String: ApiInfoNode] = [:]

    /// API 缓存有效期 (秒)
    private let cacheValidity: Int32

    // MARK: - Initialization

    /// 初始化 API 信息管理器
    /// Initialize API information manager
    public init(apiClient: ApiClientProviding,
                connectionProvider: DeviceConnectionProviding? = nil,
                storage: KeyValueStorage = UserDefaultsStorage(),
                cacheValidity: Int32 = SynologyConfig.default.apiInfoCacheValidity) {
        self.apiClient = apiClient
        self.storage = storage
        self.cacheValidity = cacheValidity
    }

    public func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
        if cachedApiInfo.isEmpty, let cached = getApiInfoFromStorage() {
            cachedApiInfo = cached
            Logger.debug("ApiInfoApi#getApiInfoByApiName load from cache: \(cached.count)")
        }

        guard let apiInfo = cachedApiInfo[apiName] else {
            Logger.info("ApiInfoApi#getApiInfoByApiName (\(apiName)) not exist")
            throw SynologyError.api(.apiNotExists(name: apiName))
        }

        Logger.info("ApiInfoApi#getApiInfoByApiName get apiInfo, key = : \(apiName), value = \(apiInfo)")
        return apiInfo
    }

    public func checkSynologyApiInfo(cacheEnabled: Bool? = false, updateCache: Bool? = true) async throws -> Bool {
        if cacheEnabled == true, isApiInfoCacheValid(validTime: cacheValidity), let cached = getApiInfoFromStorage() {
            Logger.debug("ApiInfoApi#checkSynologyApiInfo from cache: \(cached.count)")
            cachedApiInfo = cached
            return true
        }

        cachedApiInfo = try await queryApiInfoFromDsm()
        Logger.debug("ApiInfoApi#checkSynologyApiInfo from api: \(cachedApiInfo.count)")

        if updateCache == true, cachedApiInfo.isEmpty == false {
            saveApiInfoToStorage(apiInfo: cachedApiInfo)
        }
        return true
    }
}

extension ApiInfoApi {
    private func queryApiInfoFromDsm() async throws -> [String: ApiInfoNode] {
        let apiInfo: [String: ApiInfoNode] = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.Core.INFO, method: "query", parameters: ["query": "all"]),
            resultType: [String: ApiInfoNode].self
        )
        return apiInfo
    }

    private func saveApiInfoToStorage(apiInfo: [String: ApiInfoNode]) {
        if let encoded = try? JSONEncoder().encode(apiInfo),
           let jsonString = String(data: encoded, encoding: .utf8) {
            let (dataKey, timeKey) = getCacheKeys()
            storage.set(jsonString, forKey: dataKey)
            storage.set(Date(), forKey: timeKey)
        }
    }

    private func getApiInfoFromStorage() -> [String: ApiInfoNode]? {
        let (dataKey, _) = getCacheKeys()
        if let jsonString = storage.string(forKey: dataKey),
           let data = jsonString.data(using: .utf8) {
            return try? JSONDecoder().decode([String: ApiInfoNode].self, from: data)
        }
        return nil
    }

    private func getApiInfoSaveToStorageTime() -> Date? {
        let (_, timeKey) = getCacheKeys()
        return storage.object(forKey: timeKey) as? Date
    }

    /// 获取缓存 key（不再基于 host，因为同一设备 API 信息相同）
    /// Get cache keys (no longer host-based, as API info is the same for the same device)
    private func getCacheKeys() -> (dataKey: String, timeKey: String) {
        let dataKey = UserDefaultsKeys.DISK_STATION_API_INFO.keyName
        let timeKey = UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName
        return (dataKey, timeKey)
    }

    private func isApiInfoCacheValid(validTime: Int32?) -> Bool {
        if let lastUpdateTime = getApiInfoSaveToStorageTime() {
            return Int32(Date().timeIntervalSince(lastUpdateTime)) < (validTime ?? 24 * 60 * 60)
        }
        return false
    }
}
