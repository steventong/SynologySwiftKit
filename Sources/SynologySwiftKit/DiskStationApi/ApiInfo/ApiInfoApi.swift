//
//  ApiInfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiInfoApi

/// API 信息管理类 (Actor 保证并发安全)
public actor ApiInfoApi: ApiInfoProviding {

    // MARK: - Dependencies & State

    /// API 客户端
    private let apiClient: ApiClientProviding

    /// 连接提供者 (用于隔离缓存)
    private let connectionProvider: DeviceConnectionProviding?

    /// 缓存的 API 信息
    private var cachedApiInfo: [String: ApiInfoNode] = [:]

    /// 上次缓存的主机地址
    private var lastCacheHost: String?

    // MARK: - Initialization

    /// 初始化 API 信息管理器
    public init(apiClient: ApiClientProviding, connectionProvider: DeviceConnectionProviding? = nil)
    {
        self.apiClient = apiClient
        self.connectionProvider = connectionProvider
    }

    public func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
        // 检查 Host 是否变化
        await checkHostSwitch()

        if cachedApiInfo.isEmpty,
            let cached = getApiInfoFromUserDefaults()
        {
            self.cachedApiInfo = cached
            Logger.debug("ApiInfoApi#getApiInfoByApiName load from cache: \(cached.count)")
        }

        guard let apiInfo = cachedApiInfo[apiName] else {
            Logger.debug("ApiInfoApi#getApiInfoByApiName (\(apiName)) not exist")
            throw SynologyError.api(.apiNotExists(name: apiName))
        }

        return apiInfo
    }

    public func checkSynologyApiInfo(cacheEnabled: Bool? = false) async throws -> Bool {
        await checkHostSwitch()

        if cacheEnabled == true && isApiInfoCacheValid(validTime: 60 * 24 * 60 * 60),
            let cached = getApiInfoFromUserDefaults()
        {
            Logger.debug("ApiInfoApi#checkSynologyApiInfo from cache: \(cached.count)")
            self.cachedApiInfo = cached
            return true
        }

        cachedApiInfo = try await queryApiInfoFromDsm()
        Logger.debug("ApiInfoApi#checkSynologyApiInfo from api: \(cachedApiInfo.count)")

        saveApiInfoToUserDefaults(apiInfo: cachedApiInfo)
        return true
    }

    /// 检查 Host 是否切换
    private func checkHostSwitch() async {
        let currentHost = await connectionProvider?.getCurrentConnectionUrl()?.url ?? ""
        if lastCacheHost != currentHost {
            Logger.debug("ApiInfoApi#checkHostSwitch: \(lastCacheHost ?? "nil") -> \(currentHost)")
            cachedApiInfo = [:]
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
        return apiInfo
    }

    private func saveApiInfoToUserDefaults(apiInfo: [String: ApiInfoNode]) {
        if let encoded = try? JSONEncoder().encode(apiInfo),
            let jsonString = String(data: encoded, encoding: .utf8)
        {
            let (dataKey, timeKey) = getCacheKeysSync() // 这里暂时保持同步，因为 getCacheKeys 底层调用需要注意
            UserDefaults.standard.setValue(jsonString, forKey: dataKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
        }
    }

    private func getApiInfoFromUserDefaults() -> [String: ApiInfoNode]? {
        let (dataKey, _) = getCacheKeysSync()
        if let jsonString = UserDefaults.standard.string(forKey: dataKey),
            let data = jsonString.data(using: .utf8)
        {
            return try? JSONDecoder().decode([String: ApiInfoNode].self, from: data)
        }
        return nil
    }

    private func getApiInfoSaveToUserDefaultsTime() -> Date? {
        let (_, timeKey) = getCacheKeysSync()
        return UserDefaults.standard.object(forKey: timeKey) as? Date
    }

    /// 后续可能需要优化为异步，但目前 UserDefaults 操作封装为私有同步逻辑
    private func getCacheKeysSync() -> (dataKey: String, timeKey: String) {
        let baseKey = UserDefaultsKeys.DISK_STATION_API_INFO.keyName
        let baseTimeKey = UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName

        // 注意：由于 connectionProvider 是 actor，无法在同步方法中访问其接口。
        // 这里依赖 checkHostSwitch 已经同步了 lastCacheHost。
        let url = lastCacheHost ?? ""
        if url.isEmpty {
            return (baseKey, baseTimeKey)
        }

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
