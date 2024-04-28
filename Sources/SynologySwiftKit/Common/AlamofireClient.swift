//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

class AlamofireClient {
    static let shared = AlamofireClient()

    func session(timeout: TimeInterval = 10) -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = 10

        #if DEBUG
            return Session(configuration: configuration, eventMonitors: [AlamofireLoggerMonitor()])
        #else
            return Session(configuration: configuration)
        #endif
    }
    
    
}
