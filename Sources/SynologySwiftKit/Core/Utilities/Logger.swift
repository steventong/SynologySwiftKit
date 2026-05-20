import Foundation
import OSLog

// MARK: - Logger

/// SynologySwiftKit 轻量日志工具
/// Lightweight logger for SynologySwiftKit
///
/// 基于 `OSLog` 实现，通过 `isEnabled` 开关控制日志输出（默认开启）。
/// Backed by `OSLog`, controlled by the `isEnabled` switch (enabled by default).
public final class Logger {
    private static let osLog = OSLog(subsystem: "me.itwl.SynologySwiftKit", category: "SynologySwiftKit")
    private static let kitTag = "[SynologySwiftKit]"
    public static var isEnabled = true

    private init() {}

    /// 输出 Info 级别日志
    /// Log at Info level
    public static func info(_ message: String, filePath: String = #fileID, fileNumber: Int = #line) {
        log(message, type: .info, filePath: filePath, fileNumber: fileNumber)
    }

    /// 输出 Debug 级别日志
    /// Log at Debug level
    public static func debug(_ message: String, filePath: String = #fileID, fileNumber: Int = #line) {
        log(message, type: .debug, filePath: filePath, fileNumber: fileNumber)
    }

    /// 输出 Warning 级别日志
    /// Log at Warning level
    public static func warn(_ message: String, filePath: String = #fileID, fileNumber: Int = #line) {
        log(message, type: .error, filePath: filePath, fileNumber: fileNumber)
    }

    /// 输出 Error 级别日志
    /// Log at Error level
    public static func error(_ message: String, filePath: String = #fileID, fileNumber: Int = #line) {
        log(message, type: .fault, filePath: filePath, fileNumber: fileNumber)
    }

    /// 内部日志输出实现
    /// Internal log output implementation
    private static func log(_ message: String, type: OSLogType, filePath: String, fileNumber: Int) {
        guard isEnabled else { return }
        let swiftFileName = (filePath as NSString).lastPathComponent
        os_log("%{public}@ [%{public}@:%{public}d] %{public}@", log: osLog, type: type, kitTag, swiftFileName, fileNumber, message)
    }
}

extension Logger {
    static func maskedSessionValue(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "nil"
        }
        guard value.count > 8 else {
            return "<redacted>"
        }
        return "\(value.prefix(4))***\(value.suffix(4))"
    }

    static func sessionSummary(sid: String?, did: String?) -> String {
        "sid=\(maskedSessionValue(sid)), did=\(maskedSessionValue(did))"
    }

    static func connectionSummary(url: String?) -> String {
        "endpoint=\(url ?? "nil")"
    }

    static func sanitizedURLString(_ url: URL?) -> String {
        guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "nil"
        }
        components.queryItems = components.queryItems?.map {
            URLQueryItem(name: $0.name, value: sanitizedValue($0.value ?? "", forKey: $0.name))
        }
        return components.url?.absoluteString ?? url.absoluteString
    }

    static func sanitizedHeaders(_ headers: [String: String]?) -> String {
        guard let headers, !headers.isEmpty else {
            return "[:]"
        }
        return headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(sanitizedValue($0.value, forKey: $0.key))" }
            .joined(separator: "&")
    }

    static func sanitizedBodyString(_ body: Data?) -> String {
        guard let body, let bodyString = String(data: body, encoding: .utf8), !bodyString.isEmpty else {
            return "nil"
        }

        return bodyString
            .split(separator: "&")
            .map { pair in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                let key = parts.first ?? ""
                let value = parts.count > 1 ? parts[1] : ""
                return "\(key)=\(sanitizedValue(value, forKey: key))"
            }
            .joined(separator: "&")
    }

    static func sanitizedValue(_ value: String, forKey key: String) -> String {
        let lowercasedKey = key.lowercased()
        let sensitiveKeys = [
            "sid",
            "_sid",
            "did",
            "cookie",
            "authorization",
            "passwd",
            "password",
            "otp_code",
            "token",
            "synotoken",
            "ciphertoken",
        ]

        if sensitiveKeys.contains(where: { lowercasedKey.contains($0) }) {
            return "<redacted>"
        }
        return value
    }
}
