//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public enum AuthError: Error, LocalizedError {
    case commonNetworkError(String)
    case noSuchAccountOrIncorrectPassword
    case disabledAccount
    case deniedPermission
    case authenticationCodeRequired
    case authenticationCodeFailed
    case enforceAuthenticationWithCode
    case blockedIPSource
    case expiredPasswordCannotChange
    case expiredPassword
    case passwordMustBeChanged

    /**
     errorDescription
     */
    public var errorDescription: String? {
        switch self {
        case let .commonNetworkError(msg):
            return msg
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

    /**
     find error
     */
    public static func getAuthErrorByCode(errorCode: Int) -> AuthError {
        switch errorCode {
        case 400:
            noSuchAccountOrIncorrectPassword
        case 401:
            disabledAccount
        case 402:
            deniedPermission
        case 403:
            authenticationCodeRequired
        case 404:
            authenticationCodeFailed
        case 406:
            enforceAuthenticationWithCode
        case 407:
            blockedIPSource
        case 408:
            expiredPasswordCannotChange
        case 409:
            expiredPassword
        case 410:
            passwordMustBeChanged
        default:
            commonNetworkError("unknown")
        }
    }
}
