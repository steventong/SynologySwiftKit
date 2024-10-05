//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

class AlamofireLoggerMonitor: EventMonitor {
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        Logger.debug(response.debugDescription)
    }
}
