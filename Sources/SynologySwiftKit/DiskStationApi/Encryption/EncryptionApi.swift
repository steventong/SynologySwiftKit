//
//  EncryptionApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/21.
//

import Foundation

/// 加密 API（依赖注入）
/// Encryption API (dependency injection)
public class EncryptionApi {

    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    public func getApiInfoEncryption() async throws -> ApiInfoEncryption {
        let apiInfoEncryption: ApiInfoEncryption = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.Core.ENCRYPTION, method: "getinfo"),
            resultType: ApiInfoEncryption.self
        )
        Logger.info("apiInfoEncryption: \(apiInfoEncryption)")
        return apiInfoEncryption
    }
}
