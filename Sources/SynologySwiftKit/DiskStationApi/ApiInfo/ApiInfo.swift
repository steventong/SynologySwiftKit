//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

public actor ApiInfo {
    let session: Session

    public init() {
        session = AlamofireClient.shared.session()
    }

    /**
     getApiInfo
     */
    public func getApiInfo() async throws -> [String: ApiInfoNode] {
        let api = SynoDiskStationApi(api: .SYNO_API_INFO, method: "query", parameters: [
            "query": "all",
        ])

        let apiInfoList = try await api.request(resultType: [String: ApiInfoNode].self)

        Logger.info("apiInfo: \(apiInfoList)")

        return apiInfoList
    }
}
