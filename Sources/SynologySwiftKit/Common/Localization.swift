//
//  Localization.swift
//  SynologySwiftKit
//

import Foundation

enum Localization {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }
}

