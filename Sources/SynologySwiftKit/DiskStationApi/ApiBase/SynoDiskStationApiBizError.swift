//
//  File.swift
//
//
//  Created by Steven on 2024/4/28.
//

import Foundation

public enum SynoDiskStationApiBizError: Error, LocalizedError {
    case apiBizError(Int)

    public var errorDescription: String? {
        switch self {
        case let .apiBizError(errorCode):
            return "接口返回错误: \(errorCode)"
        }
    }
}
