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
           let cached = getFromUserDefaults() {
            cachedApiInfo = cached
            Logger.debug("SynologySwiftKit.ApiInfoApi, getApiInfoByApiName, load from cache: \(cachedApiInfo)")
        }

        guard let apiInfo = cachedApiInfo[apiName] else {
            throw SynoDiskStationApiError.synoApiIsNotExist(apiName)
        }

        Logger.info("apiInfo, apiName = \(apiName), apiInfo = \(apiInfo)")
        return apiInfo
    }

    /**
     queryApiInfo
     */
    public func queryApiInfo(cacheEnabled: Bool? = true) async throws {
        // 使用上次的记录, 从缓存获取，有效期一天
        if cacheEnabled == true, isApiInfoCacheValid(),
           let cachedApiInfo = getFromUserDefaults() {
            Logger.debug("SynologySwiftKit.ApiInfoApi, queryApiInfo, query from cache: \(cachedApiInfo)")
            self.cachedApiInfo = cachedApiInfo
            return
        }

        cachedApiInfo = try await queryApiInfoFromDsm()
        Logger.debug("SynologySwiftKit.ApiInfoApi, queryApiInfo, query from api: \(cachedApiInfo)")

        // save to userdefaults
        saveToUserDefaults(apiInfo: cachedApiInfo)
    }
}

extension ApiInfoApi {
    /**
     queryApiInfoFromDsm
     */
    private func queryApiInfoFromDsm() async throws -> [String: ApiInfoNode] {
        // 从接口查询
        let api = try SynoDiskStationApi(api: .SYNO_API_INFO, method: "query", version: 1, parameters: [
            "query": "all",
        ])

        let apiInfo = try await api.requestForData(resultType: [String: ApiInfoNode].self)

        Logger.info("apiInfo: \(apiInfo)")

        return apiInfo
    }

    private func saveToUserDefaults(apiInfo: [String: ApiInfoNode]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(apiInfo) {
            UserDefaults.standard.setValue(encoded, forKey: UserDefaultsKeys.DISK_STATION_API_INFO.keyName)
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName)
        }
    }

    private func getFromUserDefaults() -> [String: ApiInfoNode]? {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.DISK_STATION_API_INFO.keyName) {
            let decoder = JSONDecoder()
            return try? decoder.decode([String: ApiInfoNode].self, from: data)
        }

        return nil
    }

    private func getSaveToUserDefaultsTime() -> Date? {
        if let date = UserDefaults.standard.object(forKey: UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName) as? Date {
            return date
        }

        return nil
    }

    private func isApiInfoCacheValid() -> Bool {
        if let updateTime = getSaveToUserDefaultsTime() {
            let timeInterval = Date().timeIntervalSince(updateTime)
            // one day cache valid duration
            return timeInterval < 24 * 60 * 60
        }

        return false
    }
}
