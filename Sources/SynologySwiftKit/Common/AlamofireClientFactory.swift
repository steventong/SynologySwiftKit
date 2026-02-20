//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

class AlamofireClientFactory {
    /**
     session
     */
    static func createSession(timeoutIntervalForRequest: TimeInterval, timeoutIntervalForResource: TimeInterval = 10,
                              trustedSSLDomain: String? = nil) -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = timeoutIntervalForResource

        // 信任SSL
        let serverTrustManager = createServerTrustManager(domain: trustedSSLDomain)

        #if DEBUG
            return Session(configuration: configuration,
                           serverTrustManager: serverTrustManager,
                           eventMonitors: [AlamofireLoggerMonitor()])
        #else
            return Session(configuration: configuration,
                           serverTrustManager: serverTrustManager)
        #endif
    }

    /**
     ServerTrustManager
     https://github.com/Alamofire/Alamofire/blob/master/Documentation/AdvancedUsage.md#security
     */
    static func createServerTrustManager(domain: String?) -> ServerTrustManager? {
        if let trustedSSLDomain = domain {
            // 信任SSL
            let evaluators: [String: ServerTrustEvaluating] = [
                trustedSSLDomain: DefaultTrustEvaluator(),
            ]

            Logger.info("AlamofireClientFactory#createServerTrustManager, trust ssl cert: \(trustedSSLDomain)")

            return ServerTrustManager(evaluators: evaluators)
        }

        return nil
    }
}
