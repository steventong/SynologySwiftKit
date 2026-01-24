//
//  ApiInfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiInfoApi

/// API 信息管理类（依赖注入）
/// API information management class (dependency injection)
public class ApiInfoApi: ApiInfoProviding {

    // MARK: - Dependencies & State

    /// API 客户端
    /// API client
    private let apiClient: ApiClientProviding

    /// 缓存的 API 信息
    /// Cached API information
    private var cachedApiInfo: [String: ApiInfoNode] = [:]

    // MARK: - Initialization

    /// 初始化 API 信息管理器
    /// Initialize API information manager
    /// - Parameter apiClient: API 客户端
    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    public func getApiInfoByApiName(apiName: String) throws -> ApiInfoNode {
        if cachedApiInfo.isEmpty,
            let cachedApiInfo = getApiInfoFromUserDefaults()
        {
            self.cachedApiInfo = cachedApiInfo
            Logger.debug(
                "SynologySwiftKit.ApiInfoApi, getApiInfoByApiName, load from cache: \(cachedApiInfo.count)"
            )
        }

        guard let apiInfo = cachedApiInfo[apiName] else {
            Logger.debug(
                "SynologySwiftKit.ApiInfoApi, getApiInfoByApiName (\(apiName) not exist: \(cachedApiInfo)"
            )
            throw SynologyError.api(.apiNotExists(name: apiName))
        }

        return apiInfo
    }

    public func checkSynologyApiInfo(cacheEnabled: Bool? = false) async throws -> Bool {
        if cacheEnabled == true && isApiInfoCacheValid(validTime: 60 * 24 * 60 * 60),
            let cachedApiInfo = getApiInfoFromUserDefaults()
        {
            Logger.debug(
                "SynologySwiftKit.ApiInfoApi, queryApiInfo, query from cache, api cnt: \(cachedApiInfo.count)"
            )
            self.cachedApiInfo = cachedApiInfo
            return true
        }

        cachedApiInfo = try await queryApiInfoFromDsm()
        Logger.debug("SynologySwiftKit.ApiInfoApi, queryApiInfo, query from api: \(cachedApiInfo)")

        saveApiInfoToUserDefaults(apiInfo: cachedApiInfo)
        return true
    }
}

extension ApiInfoApi {
    private func queryApiInfoFromDsm() async throws -> [String: ApiInfoNode] {
        let apiInfo: [String: ApiInfoNode] = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.Core.INFO, method: "query", parameters: ["query": "all"]),
            resultType: [String: ApiInfoNode].self
        )
        Logger.info("apiInfo: \(apiInfo)")
        return apiInfo
    }

    private func saveApiInfoToUserDefaults(apiInfo: [String: ApiInfoNode]) {
        if let encoded = try? JSONEncoder().encode(apiInfo),
            let apiInfoJson = String(data: encoded, encoding: .utf8)
        {
            UserDefaults.standard.setValue(
                apiInfoJson, forKey: UserDefaultsKeys.DISK_STATION_API_INFO.keyName)
            UserDefaults.standard.set(
                Date(), forKey: UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName)
        }
    }

    private func getApiInfoFromUserDefaults() -> [String: ApiInfoNode]? {
        if let apiInfoJson = UserDefaults.standard.string(
            forKey: UserDefaultsKeys.DISK_STATION_API_INFO.keyName),
            let encoded = apiInfoJson.data(using: .utf8)
        {
            return try? JSONDecoder().decode([String: ApiInfoNode].self, from: encoded)
        }
        return nil
    }

    private func getApiInfoSaveToUserDefaultsTime() -> Date? {
        UserDefaults.standard.object(
            forKey: UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName) as? Date
    }

    private func isApiInfoCacheValid(validTime: Int32?) -> Bool {
        if let lastUpdateTime = getApiInfoSaveToUserDefaultsTime() {
            return Int32(Date().timeIntervalSince(lastUpdateTime)) < (validTime ?? 24 * 60 * 60)
        }
        return false
    }
}
