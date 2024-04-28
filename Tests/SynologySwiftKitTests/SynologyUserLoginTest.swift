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
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }

        let synologyUserLogin = SynologyUserLogin()
        let result = try await synologyUserLogin.login(server: SecretKey.quickConnectId, username: SecretKey.username, password: SecretKey.password)

        print(result)
    }
}
