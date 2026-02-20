//
//  File.swift
//
//
//  Created by Steven on 2024/7/7.
//

import Foundation

class JsonUtils {
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
