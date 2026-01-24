//
//  DsmInfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/5/12.
//

import Foundation

/// DSM 信息 API（依赖注入）
/// DSM Info API (dependency injection)
public class DsmInfoApi {

    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    public func queryDmsInfo() async throws -> DsmInfo? {
        let dsmInfo: DsmInfo = try await apiClient.requestForData(
            ApiEndpoint(api: SynologyApi.Core.DSM_INFO, method: "getinfo", version: 2),
            resultType: DsmInfo.self
        )
        Logger.info("dsmInfo: \(dsmInfo)")
        return dsmInfo
    }
}
