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
    
    /// 记录请求开始
    /// Log request start
    static func logRequest(
        url: URL,
        method: String,
        headers: [String: String]?,
        body: Data?
    ) {
        var log = "\n┌─────────────────────────────────────────────────────"
        log += "\n│ 📤 REQUEST"
        log += "\n├─────────────────────────────────────────────────────"
        log += "\n│ URL: \(url.absoluteString)"
        log += "\n│ Method: \(method)"
        
        if let headers = headers, !headers.isEmpty {
            log += "\n│ Headers:"
            for (key, value) in headers {
                log += "\n│   \(key): \(value)"
            }
        }
        
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            log += "\n│ Body: \(bodyString)"
        }
        
        log += "\n└─────────────────────────────────────────────────────\n"
        
        Logger.debug(log)
    }
    
    /// 记录响应
    /// Log response
    static func logResponse(
        url: URL,
        statusCode: Int,
        headers: [AnyHashable: Any]?,
        data: Data?,
        duration: TimeInterval
    ) {
        let statusEmoji = statusCode >= 200 && statusCode < 300 ? "✅" : "❌"
        let durationStr = String(format: "%.3f", duration)
        
        var log = "\n┌─────────────────────────────────────────────────────"
        log += "\n│ 📥 RESPONSE \(statusEmoji)"
        log += "\n├─────────────────────────────────────────────────────"
        log += "\n│ URL: \(url.absoluteString)"
        log += "\n│ Status: \(statusCode)"
        log += "\n│ Duration: \(durationStr)s"
        
        if let headers = headers, !headers.isEmpty {
            log += "\n│ Headers:"
            for (key, value) in headers {
                log += "\n│   \(key): \(value)"
            }
        }
        
        if let data = data {
            if let jsonString = prettyPrintJSON(data) {
                log += "\n│ Body:\n\(jsonString)"
            } else if let bodyString = String(data: data, encoding: .utf8) {
                log += "\n│ Body: \(bodyString)"
            }
        }
        
        log += "\n└─────────────────────────────────────────────────────\n"
        
        Logger.debug(log)
    }
    
    /// 记录错误
    /// Log error
    static func logError(
        url: URL,
        error: Error,
        duration: TimeInterval
    ) {
        let durationStr = String(format: "%.3f", duration)
        
        var log = "\n┌─────────────────────────────────────────────────────"
        log += "\n│ ❌ ERROR"
        log += "\n├─────────────────────────────────────────────────────"
        log += "\n│ URL: \(url.absoluteString)"
        log += "\n│ Duration: \(durationStr)s"
        log += "\n│ Error: \(error.localizedDescription)"
        log += "\n│ Details: \(error)"
        log += "\n└─────────────────────────────────────────────────────\n"
        
        Logger.error(log)
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
