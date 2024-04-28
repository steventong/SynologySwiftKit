//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

enum AuthError: LocalizedError {
    case optCodeRequired
    case passwordIncorrect

    var errorDescription: String? {
        switch self {
        case .optCodeRequired:
            return "require otp code"
        case .passwordIncorrect:
            return "incorrect username or password"
        }
    }
}
