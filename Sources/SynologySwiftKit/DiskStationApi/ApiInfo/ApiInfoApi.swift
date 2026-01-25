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

    /// 连接提供者 (用于隔离缓存)
    /// Connection provider (for cache isolation)
    private let connectionProvider: DeviceConnectionProviding?

    /// 缓存的 API 信息
    /// Cached API information
    private var cachedApiInfo: [String: ApiInfoNode] = [:]

    /// 上次缓存的主机地址
    /// Last cached host address
    private var lastCacheHost: String?

    // MARK: - Initialization

    /// 初始化 API 信息管理器
    /// Initialize API information manager
    /// - Parameters:
    ///   - apiClient: API 客户端
    ///   - connectionProvider: 连接提供者 (可选)
    public init(apiClient: ApiClientProviding, connectionProvider: DeviceConnectionProviding? = nil)
    {
        self.apiClient = apiClient
        self.connectionProvider = connectionProvider
    }

    public func getApiInfoByApiName(apiName: String) throws -> ApiInfoNode {
        // 检查 Host 是否变化
        checkHostSwitch()

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
        checkHostSwitch()

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

    /// 检查 Host 是否切换，如果切换则清空内存缓存
    private func checkHostSwitch() {
        let currentHost = connectionProvider?.getCurrentConnectionUrl()?.url ?? ""
        if lastCacheHost != currentHost {
            Logger.debug(
                "SynologySwiftKit.ApiInfoApi, host switch detected: \(lastCacheHost ?? "nil") -> \(currentHost)"
            )
            cachedApiInfo = [:]  // 清空缓存
            lastCacheHost = currentHost
        }
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
            let (dataKey, timeKey) = getCacheKeys()
            UserDefaults.standard.setValue(apiInfoJson, forKey: dataKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
        }
    }

    private func getApiInfoFromUserDefaults() -> [String: ApiInfoNode]? {
        let (dataKey, _) = getCacheKeys()
        if let apiInfoJson = UserDefaults.standard.string(forKey: dataKey),
            let encoded = apiInfoJson.data(using: .utf8)
        {
            return try? JSONDecoder().decode([String: ApiInfoNode].self, from: encoded)
        }
        return nil
    }

    private func getApiInfoSaveToUserDefaultsTime() -> Date? {
        let (_, timeKey) = getCacheKeys()
        return UserDefaults.standard.object(forKey: timeKey) as? Date
    }

    /// 获取基于 Host 的缓存 Key
    private func getCacheKeys() -> (dataKey: String, timeKey: String) {
        let baseKey = UserDefaultsKeys.DISK_STATION_API_INFO.keyName
        let baseTimeKey = UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName

        guard let url = connectionProvider?.getCurrentConnectionUrl()?.url, !url.isEmpty else {
            return (baseKey, baseTimeKey)
        }

        // 简单使用 Base64 编码 URL 作为后缀，避免非法字符
        // Simple Base64 encoding of URL as suffix to avoid illegal characters
        let suffix = Data(url.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")

        return ("\(baseKey)_\(suffix)", "\(baseTimeKey)_\(suffix)")
    }

    private func isApiInfoCacheValid(validTime: Int32?) -> Bool {
        if let lastUpdateTime = getApiInfoSaveToUserDefaultsTime() {
            return Int32(Date().timeIntervalSince(lastUpdateTime)) < (validTime ?? 24 * 60 * 60)
        }
        return false
    }
}
