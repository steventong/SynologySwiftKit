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

        guard let connection else {
            throw SynologyUserLoginError.connectionUnAvaliable
        }

        Logger.info("connection: \(connection)")
        
        
        let auth = Auth()
        let authResult = try await auth.userLogin(server: connection.url, username: username, password: password, optCode: optCode)
                
        Logger.info("authResult: \(authResult)")
    }
}

extension SynologyUserLogin {
}
