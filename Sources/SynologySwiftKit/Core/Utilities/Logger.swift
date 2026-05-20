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
