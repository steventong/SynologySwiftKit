//
//  File.swift
//
//
//  Created by Steven on 2024/5/12.
//

import Foundation

extension DsmInfoApi {
    public class DsmInfo: Decodable {
        /**
         {"data":{"codepage":"chs","model":"","ram":20480,"serial":"","temperature":61,"temperature_warn":false,"time":"Sat Feb  3 10:33:59 2024","uptime":0000,"version":"69057","version_string":"DSM 7.2.1-69057 Update 3"},"success":true}
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
}
