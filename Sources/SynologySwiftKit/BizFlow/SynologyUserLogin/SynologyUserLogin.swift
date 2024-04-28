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
    func login(server: String, username: String, password: String, optCode: String? = nil, onLoginProcessUpdate: @escaping (SynologyUserLoginStep) -> Void) async throws {
        onLoginProcessUpdate(.FETCH_CONNECTION)

        let deviceConnection = DeviceConnection()
        let connection = try await deviceConnection.getDeviceConnectionByQuickConnectId(quickConnectId: server)

        guard let connection else {
            throw SynologyUserLoginError.connectionUnAvaliable
        }

        onLoginProcessUpdate(.FETCH_CONNECTION_SUCCESS)

        Logger.info("connection: \(connection)")

        onLoginProcessUpdate(.USER_LOGIN)

        let auth = Auth()
        let authResult = try await auth.userLogin(server: connection.url, username: username, password: password, optCode: optCode)

        onLoginProcessUpdate(.USER_LOGIN_SUCCESS)

        Logger.info("authResult: \(authResult)")
    }
}

extension SynologyUserLogin {
}
