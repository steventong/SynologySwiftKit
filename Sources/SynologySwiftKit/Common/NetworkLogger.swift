//
//  NetworkLogger.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

/// 网络请求日志记录器
/// Network request logger for debugging
final class NetworkLogger {
    /// 执行请求并自动记录完整日志（请求+响应）
    /// Execute request and automatically log complete info (request + response)
    /// - Parameters:
    ///   - request: URLRequest
    ///   - session: URLSession (默认使用 shared)
    /// - Returns: (Data, URLResponse)
    static func execute(request: URLRequest, session: URLSession = .shared) async throws -> (Data, URLResponse) {
        let startTime = Date()
        let url = request.url ?? URL(string: "unknown")!
        let method = request.httpMethod ?? "GET"

        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            if let httpResponse = response as? HTTPURLResponse {
                logCombined(
                    url: url,
                    method: method,
                    requestHeaders: request.allHTTPHeaderFields,
                    requestBody: request.httpBody,
                    statusCode: httpResponse.statusCode,
                    responseHeaders: httpResponse.allHeaderFields,
                    responseData: data,
                    duration: duration,
                    error: nil
                )
            }

            return (data, response)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logCombined(
                url: url,
                method: method,
                requestHeaders: request.allHTTPHeaderFields,
                requestBody: request.httpBody,
                statusCode: nil,
                responseHeaders: nil,
                responseData: nil,
                duration: duration,
                error: error
            )
            throw error
        }
    }

    /// 合并日志打印
    /// Combined log printing
    private static func logCombined(url: URL, method: String, requestHeaders: [String: String]?, requestBody: Data?, statusCode: Int?, responseHeaders: [AnyHashable: Any]?, responseData: Data?, duration: TimeInterval, error: Error?) {
        let durationStr = String(format: "%.3f", duration)
        let statusEmoji: String
        let statusText: String

        if error != nil {
            statusEmoji = "❌"
            statusText = "ERROR"
        } else if let code = statusCode {
            statusEmoji = code >= 200 && code < 300 ? "✅" : "❌"
            statusText = "\(code)"
        } else {
            statusEmoji = "❓"
            statusText = "?"
        }

        var log = "\n┌─────────────────────────────────────────────────────"
        log += "\n│ 🔄 [\(method)] \(statusEmoji) \(statusText) (\(durationStr)s)"
        log += "\n├─────────────────────────────────────────────────────"
        log += "\n│ URL: \(url.absoluteString)"

        // 请求信息
        if let reqHeaders = requestHeaders, !reqHeaders.isEmpty {
            log += "\n│ 📤 Request Headers:"
            for (key, value) in reqHeaders {
                log += "\n│   \(key): \(value)"
            }
        }

        if let body = requestBody, let bodyString = String(data: body, encoding: .utf8) {
            log += "\n│ 📤 Request Body: \(bodyString)"
        }

        // 响应/错误信息
        log += "\n├─────────────────────────────────────────────────────"

        if let error = error {
            log += "\n│ ❌ Error: \(error.localizedDescription)"
            log += "\n│ Details: \(error)"
        } else {
            if let respHeaders = responseHeaders, !respHeaders.isEmpty {
                log += "\n│ 📥 Response Headers:"
                for (key, value) in respHeaders {
                    log += "\n│   \(key): \(value)"
                }
            }

            if let data = responseData {
                if let jsonString = prettyPrintJSON(data) {
                    log += "\n│ 📥 Response Body:\n\(jsonString)"
                } else if let bodyString = String(data: data, encoding: .utf8) {
                    log += "\n│ � Response Body: \(bodyString)"
                }
            }
        }

        log += "\n└─────────────────────────────────────────────────────\n"

        if error != nil {
            Logger.error(log)
        } else {
            Logger.debug(log)
        }
    }

    /// 格式化 JSON 输出
    private static func prettyPrintJSON(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString.components(separatedBy: "\n").map { "│   \($0)" }.joined(separator: "\n")
    }
}
