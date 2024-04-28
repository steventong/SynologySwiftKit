//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public enum SynologyUserLoginError: LocalizedError {
    case connectionUnAvaliable

    var errorDescription: String {
        switch self {
        case .connectionUnAvaliable:
            return "device connection not avaliable"
        }
    }
}
