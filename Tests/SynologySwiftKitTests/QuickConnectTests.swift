//
//  File.swift
//
//
//  Created by Steven on 2024/4/24.
//

@testable import SynologySwiftKit
import XCTest

// XCTest Documentation
// https://developer.apple.com/documentation/xctest

// Defining Test Cases and Test Methods
// https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods

final class QuickConnectTests: XCTestCase {
    let quickConnectApi = QuickConnectApi()

    /**
     删除缓存后测试
     */
    func testGetConnection() async throws {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.SYNOLOGY_SERVER_URL(SecretKey.quickConnectId).keyName)

        if let result = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: SecretKey.quickConnectId, enableHttps: false) {
            Logger.info("result = \(result)")
        } else {
            Logger.info("result = fail")
        }
    }

    /**
     不存在的qc id
     */
    func testGetConnection_invalidQC() async throws {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }

        do {
            if let result = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: "FAKE-QUICKCONNECT-ID", enableHttps: true) {
                Logger.info("result = \(result)")
            }
        } catch QuickConnectError.serverInfoNotFound {
            Logger.info("result = fail")
        }
    }
}
