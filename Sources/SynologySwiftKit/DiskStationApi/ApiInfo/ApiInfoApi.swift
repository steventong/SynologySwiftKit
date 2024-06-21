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
            Logger.debug("SynologySwiftKit.ApiInfoApi, load from cache: \(cachedApiInfo)")
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
    public func queryApiInfo() async throws {
        cachedApiInfo = try await queryApiInfoFromDsm()
        Logger.debug("SynologySwiftKit.ApiInfoApi, query from api: \(cachedApiInfo)")

        // save to userdefaults
        saveToUserDefaults(apiInfo: cachedApiInfo)
    }
}

extension ApiInfoApi {
    /**
     queryApiInfoFromDsm
     */
    private func queryApiInfoFromDsm() async throws -> [String: ApiInfoNode] {
        let api = try await SynoDiskStationApi(api: .SYNO_API_INFO, method: "query", version: 1, parameters: [
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
        }
    }

    private func getFromUserDefaults() -> [String: ApiInfoNode]? {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.DISK_STATION_API_INFO.keyName) {
            let decoder = JSONDecoder()
            return try? decoder.decode([String: ApiInfoNode].self, from: data)
        }

        return nil
    }
}
