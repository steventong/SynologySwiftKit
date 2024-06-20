//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

public actor ApiInfoApi {
    static let shared = ApiInfoApi()
    private let lock = NSLock()
    private var cacheApiInfo: [String: ApiInfoNode] = [:]

    private init() {
    }

    /**
     getApiInfo
     */
    public func getApiInfo(apiName: String) async throws -> ApiInfoNode {
        if cacheApiInfo.isEmpty {
            Logger.info("apiInfo cache is not avaliable, try to query")
            cacheApiInfo = try await getApiInfo()
        }

        guard let apiInfo = cacheApiInfo[apiName] else {
            throw SynoDiskStationApiError.synoApiIsNotExist(apiName)
        }

        Logger.info("apiInfo, apiName = \(apiName), apiInfo = \(apiInfo)")
        return apiInfo
    }

    /**
     api encryption

     api=SYNO.API.Encryption&method=getinfo&version=1
     */
    public func getApiInfoEncryption() async throws -> ApiInfoEncryption {
        let api = try await SynoDiskStationApi(api: .SYNO_API_ENCRYPTION, method: "getinfo", version: 1)

        let apiInfoEncryption = try await api.requestForData(resultType: ApiInfoEncryption.self)

        Logger.info("apiInfoEncryption: \(apiInfoEncryption)")

        return apiInfoEncryption
    }
}

extension ApiInfoApi {
    /**
     getApiInfo
     */
    private func getApiInfo() async throws -> [String: ApiInfoNode] {
        let api = try await SynoDiskStationApi(api: .SYNO_API_INFO, method: "query", version: 1, parameters: [
            "query": "all",
        ])

        let apiInfo = try await api.requestForData(resultType: [String: ApiInfoNode].self)

        Logger.info("apiInfo: \(apiInfo)")

        return apiInfo
    }
}
