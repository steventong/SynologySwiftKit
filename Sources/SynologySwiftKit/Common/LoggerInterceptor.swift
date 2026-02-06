//
//  LoggerInterceptor.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// 日志拦截器
public struct LoggerInterceptor: RequestInterceptor {
    private let enableLogging: Bool

    public init(enableLogging: Bool) {
        self.enableLogging = enableLogging
    }

    public func adapt(_ request: URLRequest, for endpoint: ApiEndpoint) async throws -> URLRequest {
        if enableLogging {
            NetworkLogger.logRequest(
                url: request.url ?? URL(string: "unknown")!,
                method: request.httpMethod ?? "GET",
                headers: request.allHTTPHeaderFields,
                body: request.httpBody
            )
        }
        return request
    }

    public func process(_ result: Result<(Data, URLResponse), Error>, for endpoint: ApiEndpoint) async throws -> Result<(Data, URLResponse), Error> {
        guard enableLogging else { return result }

        // 注意：Process 通常在请求完成后调用，这里的 duration 可能需要上下文传递，
        // 简化起见，这里只记录结果状态，详细耗时记录仍保留在 HTTPClient 内部或通过更复杂的 Context 传递。

        switch result {
        case .success(let (data, response)):
            if let httpResponse = response as? HTTPURLResponse {
                NetworkLogger.logResponse(
                    url: httpResponse.url ?? URL(string: "unknown")!,
                    statusCode: httpResponse.statusCode,
                    headers: httpResponse.allHeaderFields,
                    data: data,
                    duration: 0 // 简化处理
                )
            }
        case let .failure(error):
            NetworkLogger.logError(url: URL(string: "unknown")!, error: error, duration: 0)
        }

        return result
    }
}
