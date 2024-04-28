//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import OSLog

class Logger {
    private static let INFO = OSLog(subsystem: "me.itwl.SynologySwiftKit", category: "Info")
    private static let DEBUG = OSLog(subsystem: "me.itwl.SynologySwiftKit", category: "Info")

    // info log
    static func info(_ message: String, filePath: String = #file, fileNumber: Int = #line) {
        let swiftFileName = (filePath as NSString).lastPathComponent
        os_log("[%{public}@:%{public}d] %{public}@",
               log: INFO, type: .info,
               swiftFileName, fileNumber,
               message)
    }

    // debug log
    static func debug(_ message: String, filePath: String = #file, fileNumber: Int = #line) {
        let swiftFileName = (filePath as NSString).lastPathComponent
        os_log("[%{public}@:%{public}d] %{public}@",
               log: DEBUG, type: .debug,
               swiftFileName, fileNumber,
               message)
    }
}
