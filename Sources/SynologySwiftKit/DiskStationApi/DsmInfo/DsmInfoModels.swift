//
//  File.swift
//
//
//  Created by Steven on 2024/5/12.
//

import Foundation

public class DsmInfo: Decodable {
    /**
     {
        "data": {
           "codepage": "chs",
           "model": "DS920+",
           "ram": 20480,
           "serial": "11111111",
           "temperature": 56,
           "temperature_warn": false,
           "time": "Sun Jun  2 13:34:43 2024",
           "uptime": 3500000,
           "version": "69057",
           "version_string": "DSM 7.2.1-69057 Update 5"
        },
        "success": true
     }
     */

    public var codepage: String?
    public var model: String?
    public var ram: Int?
    public var serial: String?
    public var temperature: Int?
    public var temperature_warn: Bool?
    public var time: String?
    public var uptime: Int?
    public var version: String?
    public var version_string: String?
}

extension DsmInfoApi {
}
