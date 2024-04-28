//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

@testable import SynologySwiftKit
import XCTest

final class ApiInfoTests: XCTestCase {
    /**
     testGetApiInfo
     */
    func testGetApiInfo() async throws {
        let deviceConnection = DeviceConnection()
        let connection = try await deviceConnection.getDeviceConnectionByQuickConnectId(quickConnectId: SecretKey.quickConnectId)

        if let connection {
            Logger.info("device connection: \(connection)")

            let apiInfo = ApiInfo()
            let apiInfoList = try await apiInfo.getApiInfo()
            Logger.info("apiInfoList \(apiInfoList)")
        }
    }
}
