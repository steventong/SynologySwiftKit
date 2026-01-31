//
//  MockApiClient.swift
//  SynologySwiftKitTests
//
//  Created by Steven on 2024/6/1.
//

import Foundation
@testable import SynologySwiftKit

/// 模拟 API 客户端（用于测试上层业务逻辑）
final class MockApiClient: ApiClientProviding, @unchecked Sendable {
    var connectionProvider: DeviceConnectionProviding
    var apiInfoProvider: ApiInfoProviding? // 协议要求

    // 预设响应
    var mockResponse: Any?
    var mockError: Error?

    init() {
        // 简单的 Mock 连接提供者
        self.connectionProvider = DeviceConnection(storage: MockKeyValueStorage())
    }

    func request<T>(_ endpoint: ApiEndpoint, rawResponse: Bool) async throws -> T where T : Decodable {
        if let error = mockError {
            throw error
        }
        if let response = mockResponse as? T {
            return response
        }
        fatalError("Mock response type mismatch or not set")
    }

    func request(_ endpoint: ApiEndpoint) async throws {
        if let error = mockError {
            throw error
        }
    }

    func requestResult<T>(_ endpoint: ApiEndpoint) async -> Result<T, Error> where T : Decodable {
         if let error = mockError {
            return .failure(error)
        }
        if let response = mockResponse as? T {
            return .success(response)
        }
        return .failure(SynologyError.network(.responseEmpty))
    }

    func requestResult(_ endpoint: ApiEndpoint) async -> Result<Void, Error> {
        if let error = mockError {
            return .failure(error)
        }
        return .success(())
    }

    func buildUrl(_ endpoint: ApiEndpoint) throws -> URL {
        return URL(string: "https://mockApi.com")!
    }
}
