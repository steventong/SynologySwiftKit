//

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
   public var temperatureWarn: Bool?
   public var time: String?
   public var uptime: Int?
   public var version: String?
   public var versionString: String?

   enum CodingKeys: String, CodingKey {
      case codepage
      case model
      case ram
      case serial
      case temperature
      case temperatureWarn = "temperature_warn"
      case time
      case uptime
      case version
      case versionString = "version_string"
   }
}

extension DsmInfoApi {
}
