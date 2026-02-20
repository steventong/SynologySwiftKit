//
//  MockApiClient.swift
//  SynologySwiftKitTests
//
//  Created by Steven on 2024/6/1.
//

import Foundation
@testable import SynologySwiftKit

/// 模拟 API 客户端（用于测试上层业务逻辑）
final class MockApiClient: ApiClientProviding {
    var apiInfoProvider: ApiInfoProviding?

    var currentConnection: (type: ConnectionType, url: String)?
    var session: (sid: String, did: String?)?

    func updateConnection(type: ConnectionType, url: String) {
        currentConnection = (type, url)
    }

    func updateSession(sid: String, did: String?) {
        session = (sid, did)
    }

    func clearSession() {
        session = nil
    }

    // 预设响应
    var mockResponse: Any?
    var mockError: Error?

    init() {
    }

    func request<T: Decodable>(_ endpoint: ApiEndpoint, rawResponse: Bool) async throws -> T {
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

    func requestResult<T>(_ endpoint: ApiEndpoint) async -> Result<T, Error> where T: Decodable {
        if let error = mockError {
            return .failure(error)
        }
        if let response = mockResponse as? T {
            return .success(response)
        }
        return .failure(SynologyError.network(message: "response is empty"))
    }

    func requestResult(_ endpoint: ApiEndpoint) async -> Result<Void, Error> {
        if let error = mockError {
            return .failure(error)
        }
        return .success(())
    }

    func buildUrl(_ endpoint: ApiEndpoint) async throws -> URL {
        return URL(string: "https://mockApi.com")!
    }

    func requestRaw<T>(url: URL,
                       httpMethod: HTTPMethod,
                       headers: [String: String]?,
                       body: Data?,
                       timeout: TimeInterval) async throws -> T where T: Decodable {
        if let error = mockError {
            throw error
        }
        if let response = mockResponse as? T {
            return response
        }
        fatalError("Mock response type mismatch or not set")
    }
}
