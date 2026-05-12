//
//  Localization.swift
//  SynologySwiftKit
//

import Foundation

// MARK: - Localization

/// 本地化字符串工具
/// Localization string utility
///
/// 使用 Swift Package 内置的 `Bundle.module` 读取 `.lproj` 本地化资源。
/// Uses `Bundle.module` (Swift Package bundle) to load localized strings from `.lproj` resources.
enum Localization {
    /// 根据 key 获取本地化字符串
    /// Get localized string by key
    /// - Parameter key: 本地化资源中的 Key / Key in the localization resource
    /// - Returns: 本地化后的字符串，不存在时返回 key 本身 / Localized string, or key itself if not found
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }
}
