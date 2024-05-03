//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public enum SynoDiskStationApiCommonError: Error, LocalizedError {
    case sslConnectionFailed(String)
    case canNotFindHostError(String)
    case commonUrlError(String)
    case responseBodyEmptyError
    case requestHostNotPressentError
    case synoDiskStationApiError(Int)

    public var errorDescription: String? {
        switch self {
        case let .sslConnectionFailed(msg):
            return "请求发生了SSL错误, \(msg)"
        case let .canNotFindHostError(msg):
            return "域名解析失败, \(msg)"
        case let .commonUrlError(msg):
            return "网络请求失败, \(msg)"
        case .responseBodyEmptyError:
            return "网络请求返回结果为空"
        case .requestHostNotPressentError:
            return "请求失败，请求地址格式错误"
        case let .synoDiskStationApiError(code):
            return "接口返回错误: \(code)"
        }
    }
}
