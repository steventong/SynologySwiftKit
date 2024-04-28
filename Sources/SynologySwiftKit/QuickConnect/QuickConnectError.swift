//
//  File.swift
//
//
//  Created by Steven on 2024/4/24.
//

import Foundation

public enum QuickConnectError: LocalizedError {
    case serverInfoNotFound
    case connectionInfoNotFound

    var errorDescription: String {
        switch self {
        case .serverInfoNotFound:
            return "server info not avaliable"
        case .connectionInfoNotFound:
            return "device connection info not avaliable"
        }
    }
}
