//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

@testable import SynologySwiftKit
import XCTest

final class ApiInfoTests: XCTestCase {
    let quickConnectApi = QuickConnectApi()

    /**
     testGetApiInfo
     */
    func testGetApiInfo() async throws {
        let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: SecretKey.quickConnectId, enableHttps: true)

        if let connection {
            Logger.info("device connection: \(connection)")

            let apiInfo = ApiInfoApi()
            let apiInfoList = try await apiInfo.getApiInfo()
            Logger.info("apiInfoList \(apiInfoList)")
        }
    }
}
