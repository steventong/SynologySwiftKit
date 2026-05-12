//
//  UrlUtils.swift
//  SynologySwiftKit
//
//  Created by Steven on 2025/2/8.
//

import Foundation

// MARK: - UrlUtils

/// URL 编码工具类
/// URL encoding utility
class UrlUtils {
    /// 对字符串进行 URL 百分比编码（使用 `.urlQueryAllowed` 字符集）
    /// Percent-encode a string using the `.urlQueryAllowed` character set
    /// - Parameter value: 待编码的原始字符串 / Raw string to encode
    /// - Returns: 编码后的字符串，编码失败时返回原始值 / Encoded string, or original value on failure
    public static func urlEncode(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

extension Dictionary where Key == String, Value == ApiParameterValue {
    /// 将字典转换为 URL 编码字符串
    var urlEncodedString: String {
        self.map { key, value in
            let escapedKey = UrlUtils.urlEncode(key)
            let escapedValue = UrlUtils.urlEncode(value.stringValue)
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }

    /// 将字典转换为 URL 编码的 Data
    var urlEncodedData: Data? {
        urlEncodedString.data(using: .utf8)
    }
}
