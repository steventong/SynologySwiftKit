//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

enum AuthError: Int, LocalizedError {
    case noSuchAccountOrIncorrectPassword = 400
    case disabledAccount = 401
    case deniedPermission = 402
    case authenticationCodeRequired = 403
    case authenticationCodeFailed = 404
    case enforceAuthenticationWithCode = 406
    case blockedIPSource = 407
    case expiredPasswordCannotChange = 408
    case expiredPassword = 409
    case passwordMustBeChanged = 410

    var errorDescription: String {
        switch self {
        case .noSuchAccountOrIncorrectPassword:
            return "No such account or incorrect password."
        case .disabledAccount:
            return "Disabled account."
        case .deniedPermission:
            return "Denied permission."
        case .authenticationCodeRequired:
            return "2-factor authentication code required."
        case .authenticationCodeFailed:
            return "Failed to authenticate 2-factor authentication code."
        case .enforceAuthenticationWithCode:
            return "Enforce to authenticate with 2-factor authentication code."
        case .blockedIPSource:
            return "Blocked IP source."
        case .expiredPasswordCannotChange:
            return "Expired password cannot change."
        case .expiredPassword:
            return "Expired password."
        case .passwordMustBeChanged:
            return "Password must be changed."
        }
    }
}
