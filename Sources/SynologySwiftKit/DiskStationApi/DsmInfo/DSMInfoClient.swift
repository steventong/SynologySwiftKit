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
    private let apiClient: ApiClientProviding

    init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /// 查询 DSM 信息
    /// Query DSM information
    /// - Returns: DSM 信息
    /// - Throws: SynologyError
    public func query() async throws -> DsmInfo {
        do {
            let apiEndpoint = ApiEndpoint(api: SynologyApi.Core.DSM_INFO, method: "getinfo", version: 2)
            let dsmInfo: DsmInfo = try await apiClient.request(apiEndpoint)

            Logger.info("DSMInfoClient#query result: \(dsmInfo.model ?? "unknown")")
            return dsmInfo
        } catch let error as SynologyError {
            Logger.error("DSMInfoClient#query, error: \(error)")
            throw error
        } catch {
            Logger.error("DSMInfoClient#query, error: \(error)")
            throw SynologyError.network(message: "request failed")
        }
    }
}

// MARK: - Extensions (Potential future private methods)

private extension DSMInfoClient {
}
