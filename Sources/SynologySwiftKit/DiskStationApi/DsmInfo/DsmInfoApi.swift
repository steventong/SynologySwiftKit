//
//  DsmInfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/5/12.
//

import Foundation

/// DSM 信息 API（依赖注入）
/// DSM Info API (dependency injection)
public final class DsmInfoApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /// 查询 DSM 信息
    /// Query DSM information
    public func queryDmsInfo() async throws -> DsmInfo {
        let apiEndpoint = ApiEndpoint(api: SynologyApi.Core.DSM_INFO, method: "getinfo", version: 2)
        let dsmInfo: DsmInfo = try await apiClient.request(apiEndpoint, resultType: DsmInfo.self)

        return dsmInfo
    }

    // MARK: - DSM Info Query

    /// 查询 DSM 信息
    /// Query DSM information
    /// - Returns: DSM 信息
    /// - Throws: SynologyError
    public func queryDsmInfo() async throws -> DsmInfo {
        do {
            let apiEndpoint = ApiEndpoint(api: SynologyApi.Core.DSM_INFO, method: "getinfo", version: 2)
            let dsmInfo = try await apiClient.request(apiEndpoint, resultType: DsmInfo.self)

            Logger.info("DsmInfoApi#queryDmsInfo result: \(dsmInfo.model ?? "unknown")")
            return dsmInfo
        } catch let error as SynologyError {
            Logger.error("DsmInfoApi#queryDsmInfo, error: \(error)")
            throw error
        } catch {
            Logger.error("DsmInfoApi#queryDsmInfo, error: \(error)")
            throw SynologyError.network(.connectionFailed(underlying: error))
        }
    }
}

// MARK: - Extensions (Potential future private methods)

private extension DsmInfoApi {
}
