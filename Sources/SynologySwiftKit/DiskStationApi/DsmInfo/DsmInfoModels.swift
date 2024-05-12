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
         {"data":{"codepage":"chs","model":"DS920+","ram":20480,"serial":"2080SBRSRX48H","temperature":61,"temperature_warn":false,"time":"Sat Feb  3 10:33:59 2024","uptime":1512862,"version":"69057","version_string":"DSM 7.2.1-69057 Update 3"},"success":true}

         */

        var codepage: String?
        var model: String?
        var ram: Int?
        var serial: String?
        var temperature: Int?
        var temperature_warn: Bool?
        var time: String?
        var uptime: Int?
        var version: String?
        var version_string: String?
    }
}
