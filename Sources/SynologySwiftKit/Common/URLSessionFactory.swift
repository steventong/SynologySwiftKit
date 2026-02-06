//
//  URLSessionFactory.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

/// URLSession 工厂类，提供配置好的 URLSession 实例
final class URLSessionFactory {
    /// 创建配置好的 URLSession
    /// - Parameters:
    ///   - timeoutIntervalForRequest: 请求超时时间
    ///   - timeoutIntervalForResource: 资源超时时间
    ///   - trustedSSLDomain: 需要信任的 SSL 域名（用于自签名证书）
    /// - Returns: 配置好的 URLSession 实例
    static func createSession(timeoutIntervalForRequest: TimeInterval,
                              timeoutIntervalForResource: TimeInterval = 10,
                              trustedSSLDomain: String? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = timeoutIntervalForResource

        if let domain = trustedSSLDomain {
            let delegate = SSLTrustDelegate(trustedDomain: domain)
            #if DEBUG
                Logger.info("URLSessionFactory#createSession, trust ssl cert: \(domain)")
            #endif

            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }

        return URLSession(configuration: configuration)
    }
}

/// SSL 信任代理，用于处理自签名证书
final class SSLTrustDelegate: NSObject, URLSessionDelegate {
    private let trustedDomain: String

    init(trustedDomain: String) {
        self.trustedDomain = trustedDomain
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 处理 SSL 证书验证
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == trustedDomain,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // 信任该域名的证书
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}
