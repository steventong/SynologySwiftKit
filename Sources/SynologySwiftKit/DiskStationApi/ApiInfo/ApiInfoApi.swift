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
}
