//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import OSLog

public actor SynologyUserLogin {
    let deviceConnection = DeviceConnection()
    let auth = Auth()

    // init
    public init() {
    }

    /**
     server: quickConnectId 或者是 域名+端口号
     */
    public func login(server: String, username: String, password: String, optCode: String? = nil,
                      onLoginProcessUpdate: @escaping (SynologyUserLoginStep) -> Void,
                      onDiskStationConnectionUpdate: @escaping (ConnectionType, String) -> Void) async throws -> AuthResult {
        onLoginProcessUpdate(.STEP_START)

        let isQuickConnectID = deviceConnection.isQuickConnectId(server: server)
        let connection = try await fetchConnectionUrl(server: server, onLoginProcessUpdate: onLoginProcessUpdate)

        guard let connection else {
            onLoginProcessUpdate(.STEP_FINISH)
            throw SynologyUserLoginError.connectionUnAvaliable
        }

        onDiskStationConnectionUpdate(connection.type, connection.url)
        Logger.info("connection: \(connection)")

        if isQuickConnectID {
            onLoginProcessUpdate(.QC_USER_LOGIN)
        } else {
            onLoginProcessUpdate(.CUSTOM_DOMAIN_USER_LOGIN)
        }

        let authResult = try await auth.userLogin(server: connection.url, username: username, password: password, optCode: optCode)

        if isQuickConnectID {
            onLoginProcessUpdate(.QC_USER_LOGIN_SUCCESS)
        } else {
            onLoginProcessUpdate(.CUSTOM_DOMAIN_USER_LOGIN_SUCCESS)
        }

        Logger.info("authResult: \(authResult)")
        onLoginProcessUpdate(.STEP_FINISH)

        return authResult
    }
}

extension SynologyUserLogin {
    /**
     fetchConnectionUrl
     */
    func fetchConnectionUrl(server: String, onLoginProcessUpdate: @escaping (SynologyUserLoginStep) -> Void) async throws -> (type: ConnectionType, url: String)? {
        let isQuickConnectID = deviceConnection.isQuickConnectId(server: server)
        if isQuickConnectID {
            onLoginProcessUpdate(.QC_FETCH_CONNECTION)
            let connection = try await deviceConnection.getDeviceConnectionByQuickConnectId(quickConnectId: server)

            onLoginProcessUpdate(.QC_FETCH_CONNECTION_SUCCESS)
            return connection
        }

        return (ConnectionType.custom_domain, server)
    }
}
