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
        if let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: SecretKey.quickConnectId, enableHttps: false) {
            Logger.info("device connection: \(connection)")

            // 连接可用
            DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)
            
            // 更新API info
            try await ApiInfoApi.shared.checkSynologyApiInfo()

            let apiInfo = try ApiInfoApi.shared.getApiInfoByApiName(apiName: "SYNO.API.Info")
            Logger.info("apiInfo: \(apiInfo)")
        }
    }
}
