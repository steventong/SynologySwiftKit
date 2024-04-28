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
    /**
     删除缓存后测试
     */
    func testGetConnectionByQcIdWithoutCache() async throws {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }

        let quickConnect = QuickConnect()
        let result = try await quickConnect.getDeviceConnection(quickConnectId: "steventong")

        print(result)
    }

    /**
     带缓存测试
     */
    func testGetConnectionByQcIdWithCache() async throws {
        let quickConnect = QuickConnect()
        let result = try await quickConnect.getDeviceConnection(quickConnectId: "steventong")

        print(result)
    }
}
