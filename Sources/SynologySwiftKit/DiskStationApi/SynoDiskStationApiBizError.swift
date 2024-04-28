//
//  File.swift
//
//
//  Created by Steven on 2024/4/28.
//

import Foundation

enum SynoDiskStationApiBizError: LocalizedError {
    case apiBizError(Int)

    var errorDescription: String {
        switch self {
        case let .apiBizError(errorCode):
            return "接口返回错误: \(errorCode)"
        }
    }
}
