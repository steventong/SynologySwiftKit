//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public enum AuthError: Int, Error, LocalizedError {
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

    /**
     errorDescription
     */
    public var errorDescription: String? {
        switch self {
        case .noSuchAccountOrIncorrectPassword:
            return NSLocalizedString("NO_SUCH_ACCOUNT_OR_INCORRECT_PASSWORD", comment: "")
        case .disabledAccount:
            return NSLocalizedString("DISABLED_ACCOUNT", comment: "")
        case .deniedPermission:
            return NSLocalizedString("DENIED_PERMISSION", comment: "")
        case .authenticationCodeRequired:
            return NSLocalizedString("AUTHENTICATION_CODE_REQUIRED", comment: "")
        case .authenticationCodeFailed:
            return NSLocalizedString("AUTHENTICATION_CODE_FAILED", comment: "")
        case .enforceAuthenticationWithCode:
            return NSLocalizedString("ENFORCE_AUTHENTICATION_WITH_CODE", comment: "")
        case .blockedIPSource:
            return NSLocalizedString("BLOCKED_IP_SOURCE", comment: "")
        case .expiredPasswordCannotChange:
            return NSLocalizedString("EXPIRED_PASSWORD_CANNOT_CHANGE", comment: "")
        case .expiredPassword:
            return NSLocalizedString("EXPIRED_PASSWORD", comment: "")
        case .passwordMustBeChanged:
            return NSLocalizedString("PASSWORD_MUST_BE_CHANGED", comment: "")
        }
    }
}
