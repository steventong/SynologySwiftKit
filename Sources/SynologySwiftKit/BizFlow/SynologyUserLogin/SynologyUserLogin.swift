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
    public func login(server: String, enableHttps: Bool, username: String, password: String, otpCode: String? = nil,
                      onProgress: @escaping (SynologyUserLoginStep) -> Void,
                      onConnectionFetch: @escaping (ConnectionType, String) -> Void) async throws -> AuthResult {
        // progress
        onProgress(.STEP_START(server: server))

        // 保存登录偏好设置
        DeviceConnection.shared.updateLoginPreferences(server: server, isEnableHttps: enableHttps)

        // 获取设备地址
        guard let connection = await fetchConnectionUrl(server: server, enableHttps: enableHttps, onProgress: onProgress) else {
            // 操作结束
            onProgress(.STEP_FINISH)
            throw SynologyUserLoginError.connectionUnAvaliable
        }

        // 保存可用地址
        DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)

        // 获取地址成功
        onConnectionFetch(connection.type, connection.url)

        // 更新API info
        let _ = try await ApiInfoApi.shared.checkSynologyApiInfo(cacheEnabled: false)

        // login seever isQuickConnectID
        let isQuickConnectID = await quickConnectApi.isQuickConnectId(server: server)

        // 开始登录
        onProgress(.USER_LOGIN(isQuickConnectID ? .QUICK_CONNECT_ID : .CUSTOM_DOMAIN))

        // 登录，如果有异常会抛出，没有异常则成功
        let authResult = try await authApi.userLogin(server: connection.url, username: username, password: password, otpCode: otpCode)

        // 登录成功
        DeviceConnection.shared.updateLoginSession(username: username, sid: authResult.sid, did: authResult.did)

        Logger.info("SynologyUserLogin, userLogin by password, result: \(authResult)")
        onProgress(.USER_LOGIN_SUCCESS(isQuickConnectID ? .QUICK_CONNECT_ID : .CUSTOM_DOMAIN))

        // 查询 audio station 信息
        let audioStationInfo = try await audioStationApi.queryAudioStationInfo()
        Logger.info("SynologyUserLogin, audioStationInfo: \(audioStationInfo)")

        // 操作结束
        onProgress(.STEP_FINISH)
        return authResult
    }

    /**
     通过sid和did登录
     */
    public func login(server: String, enableHttps: Bool, username: String, sid: String, did: String?,
                      onProgress: @escaping (SynologyUserLoginStep) -> Void,
                      onConnectionFetch: @escaping (ConnectionType, String) -> Void) async throws -> AuthResult {
        // progress
        onProgress(.STEP_START(server: server))

        // 保存登录偏好设置
        DeviceConnection.shared.updateLoginPreferences(server: server, isEnableHttps: enableHttps)

        // 获取设备地址
        guard let connection = await fetchConnectionUrl(server: server, enableHttps: enableHttps, onProgress: onProgress) else {
            // 操作结束
            onProgress(.STEP_FINISH)
            throw SynologyUserLoginError.connectionUnAvaliable
        }

        // 保存可用地址
        DeviceConnection.shared.updateCurrentConnectionUrl(type: connection.type, url: connection.url)

        // 获取地址成功
        onConnectionFetch(connection.type, connection.url)

        // 更新API info
        let _ = try await ApiInfoApi.shared.checkSynologyApiInfo(cacheEnabled: false)

        // login seever isQuickConnectID
        let isQuickConnectID = await quickConnectApi.isQuickConnectId(server: server)

        // 开始登录
        onProgress(.USER_LOGIN(isQuickConnectID ? .QUICK_CONNECT_ID : .CUSTOM_DOMAIN))

        // 登录，如果有异常会抛出，没有异常则成功
        let audioStationInfo = try await audioStationApi.queryAudioStationInfo()

        // 登录成功
        DeviceConnection.shared.updateLoginSession(username: username, sid: sid, did: did)

        Logger.info("SynologyUserLogin, userLogin by session, result: \(audioStationInfo)")
        onProgress(.USER_LOGIN_SUCCESS(isQuickConnectID ? .QUICK_CONNECT_ID : .CUSTOM_DOMAIN))

        // 操作结束
        onProgress(.STEP_FINISH)

        return AuthResult(did: did, is_portal_port: false, sid: sid)
    }
}

extension SynologyUserLogin {
    /**
     fetchConnectionUrl 获取地址
     */
    private func fetchConnectionUrl(server: String, enableHttps: Bool, onProgress: @escaping (SynologyUserLoginStep) -> Void) async -> (type: ConnectionType, url: String)? {
        if await !quickConnectApi.isQuickConnectId(server: server) {
            // 自定义域名直接返回地址
            return (.custom_domain, server)
        }

        // quickConnectId 模式下，获取设备地址
        // 获取设备地址状态
        onProgress(.QC_FETCH_CONNECTION)

        // 通过quick connect 服务获取地址
        do {
            if let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: server, enableHttps: enableHttps) {
                // 新的地址
                onProgress(.QC_FETCH_CONNECTION_SUCCESS)
                return (connection.type, connection.url)
            }
        } catch {
            Logger.error("SynologyUserLogin, fetchConnectionUrl error \(error)")
        }

        return nil
    }
}
