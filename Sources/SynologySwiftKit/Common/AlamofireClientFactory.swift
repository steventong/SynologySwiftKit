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
    static func createSession(timeoutIntervalForRequest: TimeInterval, timeoutIntervalForResource: TimeInterval = 10) -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = timeoutIntervalForResource

        #if DEBUG
            return Session(configuration: configuration, eventMonitors: [AlamofireLoggerMonitor()])
        #else
            return Session(configuration: configuration)
        #endif
    }
}
