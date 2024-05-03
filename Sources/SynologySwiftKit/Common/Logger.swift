//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import OSLog

class Logger {
    private static let OS_LOG = OSLog(subsystem: "me.itwl.SynologySwiftKit", category: "SynologySwiftKit")

    // info log
    static func info(_ message: String, filePath: String = #file, fileNumber: Int = #line) {
        let swiftFileName = (filePath as NSString).lastPathComponent
        os_log("[%{public}@:%{public}d] %{public}@",
               log: OS_LOG, type: .info, swiftFileName, fileNumber, message)
    }

    // debug log
    static func debug(_ message: String, filePath: String = #file, fileNumber: Int = #line) {
        let swiftFileName = (filePath as NSString).lastPathComponent
        os_log("[%{public}@:%{public}d] %{public}@",
               log: OS_LOG, type: .debug, swiftFileName, fileNumber, message)
    }

    // warn log
    static func warn(_ message: String, filePath: String = #file, fileNumber: Int = #line) {
        let swiftFileName = (filePath as NSString).lastPathComponent
        os_log("[%{public}@:%{public}d] %{public}@",
               log: OS_LOG, type: .error, swiftFileName, fileNumber, message)
    }

    // error log
    static func error(_ message: String, filePath: String = #file, fileNumber: Int = #line) {
        let swiftFileName = (filePath as NSString).lastPathComponent
        os_log("[%{public}@:%{public}d] %{public}@",
               log: OS_LOG, type: .fault, swiftFileName, fileNumber, message)
    }
}
