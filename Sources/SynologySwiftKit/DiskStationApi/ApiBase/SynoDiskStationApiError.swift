//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public enum SynoDiskStationApiError: Error, LocalizedError {
    /**
     下面是一些通用的错误，网络异常，ssl异常等等。
     */
    case sslConnectionFailed(String)
    case canNotFindHostError(String)
    case commonUrlError(String)
    case responseBodyEmptyError
    case requestHostNotPressentError
    case synoDiskStationApiError(Int)
    /**
     下面是接口返回的异常解析
     */
    case invalidSession
    case apiBizError(Int)

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
        case .invalidSession:
            return "登录已过期，请重新登录"
        case let .apiBizError(errorCode):
            return "接口返回错误: \(errorCode)"
        }
    }
}
