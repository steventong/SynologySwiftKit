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
