//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

public actor ApiInfoApi {
    public init() {
    }

    /**
     getApiInfo
     */
    public func getApiInfo() async throws -> [String: ApiInfoNode] {
        let api = SynoDiskStationApi(api: .SYNO_API_INFO, method: "query", version: 1, parameters: [
            "query": "all",
        ])

        let apiInfoList = try await api.requestForData(resultType: [String: ApiInfoNode].self)

        Logger.info("apiInfo: \(apiInfoList)")

        return apiInfoList
    }

    /**
     api encryption

     api=SYNO.API.Encryption&method=getinfo&version=1
     */
    public func getApiInfoEncryption() async throws -> ApiInfoEncryption {
        let api = SynoDiskStationApi(api: .SYNO_API_ENCRYPTION, method: "getinfo", version: 1)

        let apiInfoEncryption = try await api.requestForData(resultType: ApiInfoEncryption.self)

        Logger.info("apiInfoEncryption: \(apiInfoEncryption)")

        return apiInfoEncryption
    }
}
