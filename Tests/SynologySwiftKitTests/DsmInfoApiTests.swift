//
//  File.swift
//
//
//  Created by Steven on 2024/5/15.
//

@testable import SynologySwiftKit
import XCTest

class DsmInfoApiTests: XCTestCase {
    let dsmInfoApi = DsmInfoApi()

    func testGetApiInfo() async {
        do {
            UserDefaults.standard.setValue("http://10.0.1.160:5000", forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
            UserDefaults.standard.setValue(1, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
           
            try await dsmInfoApi.queryDmsInfo()
        } catch {
            Logger.error("error: \(error)")
        }
    }
}
