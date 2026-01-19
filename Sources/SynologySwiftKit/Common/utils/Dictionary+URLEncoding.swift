//
//  Dictionary+URLEncoding.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

extension Dictionary where Key == String, Value == Any {
    /// 将字典转换为 URL 编码字符串
    var urlEncodedString: String {
        self.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(value)"
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }
    
    /// 将字典转换为 URL 编码的 Data
    var urlEncodedData: Data? {
        urlEncodedString.data(using: .utf8)
    }
}
