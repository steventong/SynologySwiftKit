//
//  DSMInfoClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/5/12.
//

import Foundation

/// DSM 信息 API（依赖注入）
/// DSM Info API (dependency injection)
public final class DSMInfoClient {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// Queries DSM info with an explicit SID, without ambient cookies or session invalidation.
    /// Preserves the full API envelope, including rejection codes, for diagnostics.
    public func queryEnvelope(sid: String) async throws -> DSMReadResponse {
        try await apiClient.requestEnvelope(ApiEndpoint(
            api: SynologyApi.Core.DSM_INFO, method: "getinfo", version: 2,
            httpMethod: .get, sidOnQuery: false, sidOnCookie: false
        ) {
            ("_sid", sid)
        })
    }

    /// 查询 DSM 信息
    /// Query DSM information
    /// - Returns: DSM 信息
    /// Uses the current SID without ambient cookies. Preserves cancellation and underlying errors.
    public func query() async throws -> DsmInfo {
        do {
            let apiEndpoint = ApiEndpoint(api: SynologyApi.Core.DSM_INFO, method: "getinfo", version: 2,
                                          sidOnQuery: true, sidOnCookie: false)
            let dsmInfo: DsmInfo = try await apiClient.request(apiEndpoint)

            Logger.info("DSMInfoClient#query result: \(dsmInfo.model ?? "unknown")")
            return dsmInfo
        } catch {
            Logger.error("DSMInfoClient#query, error: \(error)")
            throw error
        }
    }
}

// MARK: - Extensions (Potential future private methods)

private extension DSMInfoClient {
}
