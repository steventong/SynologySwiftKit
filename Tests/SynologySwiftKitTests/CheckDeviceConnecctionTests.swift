//
//  File.swift
//
//
//  Created by Steven on 2024/5/4.
//

@testable import SynologySwiftKit
import XCTest

final class CheckDeviceConnecctionTests: XCTestCase {
    /**
     testCheckDeviceStatus
     */
    @MainActor
    func testCheckDeviceStatus() throws {
        CheckDeviceConnection.shared.checkConnectionStatus(onSuccess: { type, url in
            Logger.info("testCheckDeviceStatus, onSuccess, connection = \(type) \(url)")
        }, onFailed: {
            Logger.info("testCheckDeviceStatus, onFailed")
        }, onLoginRequired: {
            Logger.info("testCheckDeviceStatus, onLoginRequired")
        })
    }
}
