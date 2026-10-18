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

    /// 读取 DSM 加密参数。
    ///
    /// GET SYNO.API.Encryption/getinfo v1，无业务参数；不自动加密 AuthClient 的密码请求。
    /// - Returns: cipherkey、ciphertoken、publicKey 和 serverTime。
    /// - Throws: 路由发现、网络、服务端拒绝或解码错误。
    public func queryInfo() async throws -> ApiInfoEncryption {
        let apiInfoEncryption: ApiInfoEncryption = try await apiClient.request(ApiEndpoint(api: SynologyApi.Core.ENCRYPTION, method: "getinfo"))
        Logger.info("apiInfoEncryption: \(apiInfoEncryption)")
        return apiInfoEncryption
    }
}
