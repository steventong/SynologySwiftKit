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
            Logger.debug("SynologySwiftKit.ApiInfoApi, getApiInfoByApiName (\(apiName) not exist: \(cachedApiInfo)")
            throw DiskStationApiError.synoApiIsNotExist(apiName)
        }

        return apiInfo
    }

    /**
     queryApiInfo
     */
    public func checkSynologyApiInfo(cacheEnabled: Bool? = false) async throws {
        if cacheEnabled == true && isApiInfoCacheValid(validTime: 60 * 24 * 60 * 60),
           let cachedApiInfo = getApiInfoFromUserDefaults() {
            Logger.debug("SynologySwiftKit.ApiInfoApi, queryApiInfo, query from cache, api cnt: \(cachedApiInfo.count)")
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
    private func getApiInfoSaveToUserDefaultsTime() -> Date? {
        if let date = UserDefaults.standard.object(forKey: UserDefaultsKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName) as? Date {
            return date
        }

        return nil
    }

    /**
     check time is expired or not (1 day valid)
     */
    private func isApiInfoCacheValid(validTime: Int32?) -> Bool {
        if let lastUpdateTime = getApiInfoSaveToUserDefaultsTime() {
            let timeInterval = Date().timeIntervalSince(lastUpdateTime)
            return Int32(timeInterval) < (validTime ?? 24 * 60 * 60)
        }

        return false
    }
}
