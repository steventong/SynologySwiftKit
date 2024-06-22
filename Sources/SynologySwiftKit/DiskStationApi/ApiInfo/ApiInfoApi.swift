//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

public class ApiInfoApi {
    static let shared = ApiInfoApi()
    private var cachedApiInfo: [String: ApiInfoNode] = [:]

    private init() {
    }

    /**
     getApiInfo
     */
    public func getApiInfoByApiName(apiName: String) throws -> ApiInfoNode {
        if cachedApiInfo.isEmpty,
           let cachedApiInfo = getApiInfoFromUserDefaults() {
            self.cachedApiInfo = cachedApiInfo
            Logger.debug("SynologySwiftKit.ApiInfoApi, getApiInfoByApiName, load from cache: \(cachedApiInfo)")
        }

        guard let apiInfo = cachedApiInfo[apiName] else {
            throw DiskStationApiError.synoApiIsNotExist(apiName)
        }

//        Logger.info("apiInfo, apiName = \(apiName), apiInfo = \(apiInfo)")
        return apiInfo
    }

    /**
     queryApiInfo
     */
    public func queryApiInfo(cacheEnabled: Bool? = true) async throws {
        // 使用上次的记录, 从缓存获取，有效期一天
        if cacheEnabled == true, isApiInfoCacheValid(),
           let cachedApiInfo = getApiInfoFromUserDefaults() {
            Logger.debug("SynologySwiftKit.ApiInfoApi, queryApiInfo, query from cache: \(cachedApiInfo)")
            self.cachedApiInfo = cachedApiInfo
            return
        }

        cachedApiInfo = try await queryApiInfoFromDsm()
        Logger.debug("SynologySwiftKit.ApiInfoApi, queryApiInfo, query from api: \(cachedApiInfo)")

        // save to userdefaults
        saveApiInfoToUserDefaults(apiInfo: cachedApiInfo)
    }
}

extension ApiInfoApi {
    /**
     queryApiInfoFromDsm
     */
    private func queryApiInfoFromDsm() async throws -> [String: ApiInfoNode] {
        // 从接口查询
        let api = try DiskStationApi(api: .SYNO_API_INFO, method: "query", version: 1, parameters: [
            "query": "all",
        ])

        let apiInfo = try await api.requestForData(resultType: [String: ApiInfoNode].self)

        Logger.info("apiInfo: \(apiInfo)")

        return apiInfo
    }

    /**
     save to user defaults
     */
    private func saveApiInfoToUserDefaults(apiInfo: [String: ApiInfoNode]) {
        if let encoded = try? JSONEncoder().encode(apiInfo),
           let apiInfoJson = String(data: encoded, encoding: .utf8) {
            UserDefaults.standard.setValue(apiInfoJson, forKey: UserDefaultsKeys.DISK_STATION_API_INFO.keyName)
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName)
        }
    }

    /**
     get from user defaults
     */
    private func getApiInfoFromUserDefaults() -> [String: ApiInfoNode]? {
        if let apiInfoJson = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_API_INFO.keyName),
           let encoded = apiInfoJson.data(using: .utf8) {
            return try? JSONDecoder().decode([String: ApiInfoNode].self, from: encoded)
        }

        return nil
    }

    /**
     get update time
     */
    private func getSaveToUserDefaultsTime() -> Date? {
        if let date = UserDefaults.standard.object(forKey: UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName) as? Date {
            return date
        }

        return nil
    }

    /**
     check time is expired or not (1 day valid)
     */
    private func isApiInfoCacheValid() -> Bool {
        if let updateTime = getSaveToUserDefaultsTime() {
            let timeInterval = Date().timeIntervalSince(updateTime)
            // one day cache valid duration
            return timeInterval < 24 * 60 * 60
        }

        return false
    }
}
