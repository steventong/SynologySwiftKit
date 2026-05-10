//
//  JsonUtils.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/7/7.
//

import Foundation

// MARK: - JsonUtils

/// JSON 序列化工具类
/// JSON serialization utility
class JsonUtils {
    /// 将 Codable 对象编码为 JSON 字符串
    /// Encode a Codable object to a JSON string
    /// - Parameter codable: 待编码的对象 / Object to encode
    /// - Returns: JSON 字符串，编码失败时返回 nil / JSON string, or nil on failure
    public static func toJson(codable: Codable) -> String? {
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(codable)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            Logger.error("Failed to encode JSON: \(error)")
        }

        return nil
    }
}
