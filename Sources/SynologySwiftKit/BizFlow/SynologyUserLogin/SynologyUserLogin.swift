//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import OSLog

public actor SynologyUserLogin {
    /**
     server: quickConnectId 或者是 域名+端口号
     */
    func login(server: String, username: String, password: String, optCode: String? = nil) async throws {
        let deviceConnection = DeviceConnection()
        let connection = try await deviceConnection.getDeviceConnectionByQuickConnectId(quickConnectId: server)
        Logger.info("connection: \(connection)")

        guard let connection else {
            throw SynologyUserLoginError.connectionUnAvaliable
        }
    }
}

extension SynologyUserLogin {
}
