//
//  UrlUtils.swift
//  SynologySwiftKit
//
//  Created by Steven on 2025/2/8.
//

import Foundation

class UrlUtils {
    /**
     url coded
     */
    public static func urlEncode(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

extension Dictionary where Key == String, Value == Any {
    /// 将字典转换为 URL 编码字符串
    var urlEncodedString: String {
        self.map { key, value in
            let escapedKey = UrlUtils.urlEncode(key)
            let escapedValue = UrlUtils.urlEncode("\(value)")
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }

    /// 将字典转换为 URL 编码的 Data
    var urlEncodedData: Data? {
        urlEncodedString.data(using: .utf8)
    }
}

