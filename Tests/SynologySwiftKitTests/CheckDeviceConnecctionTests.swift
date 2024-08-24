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
    func testCheckDeviceStatus() async throws {
        let checkDeviceConnection = CheckDeviceConnection()

        checkDeviceConnection.checkConnectionStatus(fetchNewServerByQuickConnectId: true,
                                                    onFinish: { success, connection in
                                                        Logger.info("testCheckDeviceStatus, success = \(success)")

                                                        if let connection = connection {
                                                            Logger.info("testCheckDeviceStatus, connection = \(connection)")
                                                        }
                                                    }, onLoginRequired: {
                                                        Logger.info("testCheckDeviceStatus, onLoginRequired")
                                                    })
    }
}
