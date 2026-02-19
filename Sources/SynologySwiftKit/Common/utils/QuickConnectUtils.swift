//
//  File.swift
//  SynologySwiftKit
//
//  Created by Steven on 19/02/2026.
//

import Foundation

class QuickConnectUtils {
    /// 判断是否是 QuickConnect ID
    /// Check if the server string is a QuickConnect ID
    public nonisolated static func isQuickConnectId(server: String) -> Bool {
        return !server.contains(".")
    }
}
