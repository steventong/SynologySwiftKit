//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

class AlamofireLoggerMonitor: EventMonitor {
    // Event called when any type of Request is resumed.
    func requestDidResume(_ request: Request) {
    }

    // Event called whenever a DataRequest has parsed a response.
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        Logger.debug(response.debugDescription)
    }
}
