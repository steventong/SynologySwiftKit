//
//  NetworkError.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

/// 网络层错误
public enum NetworkError: Error, LocalizedError {
    /// 无效的响应
    case invalidResponse
    /// HTTP 状态码错误
    case httpError(statusCode: Int)
    /// 解码错误
    case decodingError(Error)
    /// 请求失败
    case requestFailed(Error)
    /// 无效的 URL
    case invalidURL(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Server response invalid."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        }
    }
}
