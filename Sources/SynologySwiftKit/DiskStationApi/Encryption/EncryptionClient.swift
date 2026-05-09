//
//  EncryptionClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/21.
//

import Foundation

/// 加密 API（依赖注入）
/// Encryption API (dependency injection)
public final class EncryptionClient {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    public func queryInfo() async throws -> ApiInfoEncryption {
        let apiInfoEncryption: ApiInfoEncryption = try await apiClient.request(ApiEndpoint(api: SynologyApi.Core.ENCRYPTION, method: "getinfo"))
        Logger.info("apiInfoEncryption: \(apiInfoEncryption)")
        return apiInfoEncryption
    }
}
