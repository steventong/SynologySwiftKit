import Foundation
import os

public enum SynologyLogLevel: Sendable {
    case debug
    case info
    case warning
    case error
}

public enum SynologyLogDestination: Sendable {
    case system
    case handler
    case systemAndHandler
}

public struct SynologyLogRecord: Sendable {
    public let level: SynologyLogLevel
    public let message: String
    public let file: String
    public let line: Int
    public let timestamp: Date

    public init(level: SynologyLogLevel, message: String, file: String, line: Int, timestamp: Date = Date()) {
        self.level = level
        self.message = message
        self.file = file
        self.line = line
        self.timestamp = timestamp
    }
}

public typealias SynologyLogHandler = @Sendable (SynologyLogRecord) -> Void

// MARK: - Logger

/// SynologySwiftKit 轻量日志工具
/// Lightweight logger for SynologySwiftKit
///
/// 默认输出到 Apple Unified Logging，也支持通过 handler 注入给宿主 App。
/// Outputs to Apple Unified Logging by default and can optionally forward logs to a host app handler.
public final class Logger {
    private struct Configuration {
        var isEnabled = true
        var destination: SynologyLogDestination = .system
        var handler: SynologyLogHandler?
    }

    private static let lock = NSLock()
    private static let subsystem = "me.itwl.SynologySwiftKit"
    private static let category = "SynologySwiftKit"
    private static let osLogger = os.Logger(subsystem: subsystem, category: category)
    private static let kitTag = "[SynologySwiftKit]"
    private static var configuration = Configuration()

    public static var isEnabled: Bool {
        get {
            lock.withLock { configuration.isEnabled }
        }
        set {
            lock.withLock { configuration.isEnabled = newValue }
        }
    }

    public static var destination: SynologyLogDestination {
        get {
            lock.withLock { configuration.destination }
        }
        set {
            lock.withLock { configuration.destination = newValue }
        }
    }

    public static var handler: SynologyLogHandler? {
        get {
            lock.withLock { configuration.handler }
        }
        set {
            lock.withLock { configuration.handler = newValue }
        }
    }

    private init() {}

    /// 输出 Info 级别日志
    /// Log at Info level
    public static func info(_ message: String, filePath: String = #fileID, fileNumber: Int = #line) {
        log(message, level: .info, filePath: filePath, fileNumber: fileNumber)
    }

    /// 输出 Debug 级别日志
    /// Log at Debug level
    public static func debug(_ message: String, filePath: String = #fileID, fileNumber: Int = #line) {
        log(message, level: .debug, filePath: filePath, fileNumber: fileNumber)
    }

    /// 输出 Warning 级别日志
    /// Log at Warning level
    public static func warn(_ message: String, filePath: String = #fileID, fileNumber: Int = #line) {
        log(message, level: .warning, filePath: filePath, fileNumber: fileNumber)
    }

    /// 输出 Error 级别日志
    /// Log at Error level
    public static func error(_ message: String, filePath: String = #fileID, fileNumber: Int = #line) {
        log(message, level: .error, filePath: filePath, fileNumber: fileNumber)
    }

    /// 内部日志输出实现
    /// Internal log output implementation
    private static func log(_ message: String, level: SynologyLogLevel, filePath: String, fileNumber: Int) {
        let currentConfiguration = lock.withLock { configuration }
        guard currentConfiguration.isEnabled else { return }

        let swiftFileName = (filePath as NSString).lastPathComponent
        let record = SynologyLogRecord(
            level: level,
            message: OperationDiagnostics.currentID.map { "sdkOperation=\($0) " + message } ?? message,
            file: swiftFileName,
            line: fileNumber
        )

        switch currentConfiguration.destination {
        case .system:
            writeToSystem(record)
        case .handler:
            currentConfiguration.handler?(record)
        case .systemAndHandler:
            writeToSystem(record)
            currentConfiguration.handler?(record)
        }
    }

    private static func writeToSystem(_ record: SynologyLogRecord) {
        let formattedMessage = "\(kitTag) [\(record.file):\(record.line)] \(record.message)"
        osLogger.log(level: osLogLevel(for: record.level), "\(formattedMessage)")
    }

    private static func osLogLevel(for level: SynologyLogLevel) -> OSLogType {
        switch level {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .error
        case .error:
            return .fault
        }
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

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}

/// 记录异步操作各阶段的耗时；等待期间通过独立计时器输出进度。
internal final class OperationDiagnostics: @unchecked Sendable {
    @TaskLocal static var currentID: String?
    let id = UUID().uuidString
    private let label: String
    private let parent = OperationDiagnostics.currentID ?? "none"
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private let lock = NSLock()
    private var stage = "begin"
    private var cancelled = false
    private var finished = false
    private var watcher: Task<Void, Never>?

    init(_ label: String) {
        self.label = label
        emit("begin")
        watcher = Task.detached { [weak self] in
            var delay: UInt64 = 5
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: delay * 1_000_000_000) } catch { return }
                guard let self else { return }
                if self.lock.withLock({ self.finished }) { return }
                self.emit("waiting", warning: true)
                delay = min(delay * 2, 60)
            }
        }
    }

    deinit { watcher?.cancel() }

    func measure<T>(_ stage: String, operation: () async throws -> T) async rethrows -> T {
        lock.withLock { self.stage = stage }
        emit("stage.begin")
        return try await withTaskCancellationHandler {
            do {
                let result = try await Self.$currentID.withValue(id) {
                    try await operation()
                }
                emit("stage.returned")
                return result
            } catch {
                let value = error as NSError
                let underlying = value.userInfo[NSUnderlyingErrorKey] as? NSError
                emit("stage.failed domain=\(value.domain) code=\(value.code) underlying=\(underlying?.domain ?? "none"):\(underlying?.code ?? 0)", warning: true)
                throw error
            }
        } onCancel: {
            self.lock.withLock { self.cancelled = true }
            self.emit("cancel.requested", warning: true)
        }
    }

    func finish() {
        lock.withLock { finished = true }
        watcher?.cancel()
        emit("returned")
    }

    private func emit(_ event: String, warning: Bool = false) {
        let snapshot = lock.withLock { (stage, cancelled) }
        let message = "SDK operation \(event), operation=\(id), parent=\(parent), name=\(label), stage=\(snapshot.0), cancelRequested=\(snapshot.1), elapsedMs=\(Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000))"
        if warning { Logger.warn(message) } else { Logger.debug(message) }
    }
}
