//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

@testable import SynologySwiftKit
import XCTest

final class SynologyUserLoginTest: XCTestCase {
    /**
     删除缓存后测试
     */
    func testUserLoginWithoutCache() async throws {
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.SYNOLOGY_SERVER_URL(SecretKey.quickConnectId).keyName)
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_ID.keyName)
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_NAME.keyName)

        let synologyUserLogin = SynologyUserLogin()
        let result = try await synologyUserLogin.login(server: SecretKey.quickConnectId, username: SecretKey.username, password: SecretKey.password,
                                                       optCode: "")

        print(result)
    }
}
