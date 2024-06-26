//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import OSLog

public actor SynologyUserLogin {
    let quickConnectApi = QuickConnectApi()
    let authApi = AuthApi()
    let audioStationApi = AudioStationApi()

    // init
    public init() {
    }

    /**
     server: quickConnectId 或者是 域名+端口号
     */
    public func login(server: String, username: String, password: String, otpCode: String? = nil, enableHttps: Bool,
                      onLoginStepUpdate: @escaping (SynologyUserLoginStep) -> Void,
                      onConnectionFetch: @escaping (ConnectionType, String) -> Void) async throws -> AuthResult {
        onLoginStepUpdate(.STEP_START)

        // 保存登录偏好设置
        DeviceConnection.shared.updateLoginPreferences(server: server, isEnableHttps: enableHttps)

        // 获取设备地址
        let connection = try await fetchConnectionUrl(server: server, enableHttps: enableHttps, onLoginStepUpdate: onLoginStepUpdate)

        guard let connection else {
            // 操作结束
            onLoginStepUpdate(.STEP_FINISH)
            throw SynologyUserLoginError.connectionUnAvaliable
        }

        // 保存可用地址
        DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)

        // 获取地址成功
        onConnectionFetch(connection.type, connection.url)

        // 更新API info
        try await ApiInfoApi.shared.queryApiInfo(cacheEnabled: false)

        // login seever isQuickConnectID
        let isQuickConnectID = await quickConnectApi.isQuickConnectId(server: server)

        // 开始登录
        onLoginStepUpdate(.USER_LOGIN(isQuickConnectID ? .QUICK_CONNECT_ID : .CUSTOM_DOMAIN))

        // 登录，如果有异常会抛出，没有异常则成功
        let authResult = try await authApi.userLogin(server: connection.url, username: username, password: password, otpCode: otpCode)

        // 登录成功
        DeviceConnection.shared.updateLoginSession(sid: authResult.sid, did: authResult.did)

        Logger.info("SynologyUserLogin, userLogin, result: \(authResult)")
        onLoginStepUpdate(.USER_LOGIN_SUCCESS(isQuickConnectID ? .QUICK_CONNECT_ID : .CUSTOM_DOMAIN))

        // 查询 audio station 信息
        let audioStationInfo = try await audioStationApi.queryAudioStationInfo()
        Logger.info("SynologyUserLogin, audioStationInfo: \(audioStationInfo)")

        // 操作结束
        onLoginStepUpdate(.STEP_FINISH)

        return authResult
    }
}

extension SynologyUserLogin {
    /**
     fetchConnectionUrl 获取地址
     */
    func fetchConnectionUrl(server: String, enableHttps: Bool, onLoginStepUpdate: @escaping (SynologyUserLoginStep) -> Void) async throws -> (type: ConnectionType, url: String)? {
        let isQuickConnectID = await quickConnectApi.isQuickConnectId(server: server)

        // quickConnectId 模式下，获取设备地址
        if isQuickConnectID {
            onLoginStepUpdate(.QC_FETCH_CONNECTION)
            // 获取设备地址
            let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: server, enableHttps: enableHttps)
            onLoginStepUpdate(.QC_FETCH_CONNECTION_SUCCESS)
            return connection
        }

        // 自定义域名直接返回地址
        return (.custom_domain, server)
    }
}
