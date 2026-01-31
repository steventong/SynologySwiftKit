//
//  SynologyUserLogin.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import OSLog

// MARK: - SynologyUserLogin

/// Synology 用户登录管理（依赖注入）
/// Synology user login management (dependency injection)
public actor SynologyUserLogin {
    // MARK: - Dependencies

    private let deviceConnection: DeviceConnectionProviding
    private let apiInfoApi: ApiInfoProviding
    private let quickConnectApi: QuickConnectApi
    private let authApi: AuthApi
    private let audioStationApi: AudioStationApi

    // MARK: - Initialization

    /// 初始化登录管理器
    /// Initialize login manager
    /// - Parameters:
    ///   - deviceConnection: 设备连接提供者
    ///   - apiInfoApi: API 信息提供者
    ///   - apiClient: API 客户端
    public init(deviceConnection: DeviceConnectionProviding,
                apiInfoApi: ApiInfoProviding,
                apiClient: ApiClientProviding) {
        self.deviceConnection = deviceConnection
        self.apiInfoApi = apiInfoApi

        quickConnectApi = QuickConnectApi(deviceConnection: deviceConnection)
        authApi = AuthApi(apiClient: apiClient)
        audioStationApi = AudioStationApi(apiClient: apiClient)
    }
    
    // MARK: - Password Login (AsyncStream)
    
    /// 通过密码登录（AsyncStream 版本）
    /// Login with password (AsyncStream version)
    /// - Parameters:
    ///   - server: QuickConnect ID 或自定义域名
    ///   - enableHttps: 是否启用 HTTPS
    ///   - username: 用户名
    ///   - password: 密码
    ///   - otpCode: 可选的 OTP 代码
    /// - Returns: AsyncStream 返回登录进度
    public func login(
        server: String,
        enableHttps: Bool,
        username: String,
        password: String,
        otpCode: String? = nil
    ) -> AsyncStream<LoginProgress> {
        AsyncStream { continuation in
            Task {
                await self.performPasswordLogin(
                    server: server,
                    enableHttps: enableHttps,
                    username: username,
                    password: password,
                    otpCode: otpCode,
                    continuation: continuation
                )
            }
        }
    }
    
    /// 执行密码登录
    /// Perform password login
    private func performPasswordLogin(
        server: String,
        enableHttps: Bool,
        username: String,
        password: String,
        otpCode: String?,
        continuation: AsyncStream<LoginProgress>.Continuation
    ) async {
        continuation.yield(.started(server: server))
        
        // 保存登录偏好设置
        deviceConnection.updateLoginPreferences(server: server, isEnableHttps: enableHttps)
        
        // 获取连接地址
        guard let connection = await fetchConnectionUrl(
            server: server,
            enableHttps: enableHttps,
            continuation: continuation
        ) else {
            continuation.yield(.failed(error: .connectionUnavailable))
            continuation.finish()
            return
        }
        
        // 保存可用地址
        deviceConnection.updateCurrentConnectionUrl(type: connection.type, url: connection.url)
        
        // 确定服务器类型
        let isQuickConnectID = await quickConnectApi.isQuickConnectId(server: server)
        let serverType: ServerType = isQuickConnectID ? .quickConnectId : .customDomain
        
        // 更新 API 信息
        continuation.yield(.updatingApiInfo)
        do {
            _ = try await apiInfoApi.checkSynologyApiInfo(cacheEnabled: false)
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, API info fetch failed: \(error)")
            continuation.yield(.failed(error: .apiInfoFetchFailed(message: error.localizedDescription)))
            continuation.finish()
            return
        }
        
        // 开始认证
        continuation.yield(.authenticating(serverType: serverType))
        
        do {
            let authResult = try await authApi.userLogin(
                server: connection.url,
                username: username,
                password: password,
                otpCode: otpCode
            )
            
            // 登录成功，保存会话
            deviceConnection.updateLoginSession(
                username: username,
                sid: authResult.sid,
                did: authResult.did
            )
            
            Logger.info("SynologyUserLogin#performPasswordLogin, result: \(authResult)")
            
            let loginResult = LoginResult(
                sid: authResult.sid,
                did: authResult.did,
                connectionType: connection.type,
                connectionUrl: connection.url,
                serverType: serverType
            )
            continuation.yield(.loginSuccess(result: loginResult))
            
            // 验证 AudioStation
            continuation.yield(.verifyingAudioStation)
            let audioStationInfo = try await audioStationApi.info.query()
            Logger.info("SynologyUserLogin#performPasswordLogin, audioStationInfo: \(audioStationInfo)")
            
            // 完成
            continuation.yield(.completed(result: loginResult))
            continuation.finish()
            
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, auth failed: \(error)")
            continuation.yield(.failed(error: .authenticationFailed(message: error.localizedDescription)))
            continuation.finish()
        }
    }
    
    // MARK: - Session Login (AsyncStream)
    
    /// 通过 Session 登录（AsyncStream 版本）
    /// Login with session (AsyncStream version)
    /// - Parameters:
    ///   - server: QuickConnect ID 或自定义域名
    ///   - enableHttps: 是否启用 HTTPS
    ///   - username: 用户名
    ///   - sid: Session ID
    ///   - did: Device ID
    /// - Returns: AsyncStream 返回登录进度
    public func login(
        server: String,
        enableHttps: Bool,
        username: String,
        sid: String,
        did: String?
    ) -> AsyncStream<LoginProgress> {
        AsyncStream { continuation in
            Task {
                await self.performSessionLogin(
                    server: server,
                    enableHttps: enableHttps,
                    username: username,
                    sid: sid,
                    did: did,
                    continuation: continuation
                )
            }
        }
    }
    
    /// 执行 Session 登录
    /// Perform session login
    private func performSessionLogin(
        server: String,
        enableHttps: Bool,
        username: String,
        sid: String,
        did: String?,
        continuation: AsyncStream<LoginProgress>.Continuation
    ) async {
        continuation.yield(.started(server: server))
        
        // 保存登录偏好设置
        deviceConnection.updateLoginPreferences(server: server, isEnableHttps: enableHttps)
        
        // 获取连接地址
        guard let connection = await fetchConnectionUrl(
            server: server,
            enableHttps: enableHttps,
            continuation: continuation
        ) else {
            continuation.yield(.failed(error: .connectionUnavailable))
            continuation.finish()
            return
        }
        
        // 保存可用地址
        deviceConnection.updateCurrentConnectionUrl(type: connection.type, url: connection.url)
        
        // 确定服务器类型
        let isQuickConnectID = await quickConnectApi.isQuickConnectId(server: server)
        let serverType: ServerType = isQuickConnectID ? .quickConnectId : .customDomain
        
        // 更新 API 信息
        continuation.yield(.updatingApiInfo)
        do {
            _ = try await apiInfoApi.checkSynologyApiInfo(cacheEnabled: false)
        } catch {
            Logger.error("SynologyUserLogin#performSessionLogin, API info fetch failed: \(error)")
            continuation.yield(.failed(error: .apiInfoFetchFailed(message: error.localizedDescription)))
            continuation.finish()
            return
        }
        
        // 开始验证会话
        continuation.yield(.authenticating(serverType: serverType))
        
        do {
            // 通过查询 AudioStation 验证会话
            let audioStationInfo = try await audioStationApi.info.query(sid: sid, did: did)
            
            // 登录成功，保存会话
            deviceConnection.updateLoginSession(username: username, sid: sid, did: did)
            
            Logger.info("SynologyUserLogin#performSessionLogin, audioStationInfo: \(audioStationInfo)")
            
            let loginResult = LoginResult(
                sid: sid,
                did: did,
                connectionType: connection.type,
                connectionUrl: connection.url,
                serverType: serverType
            )
            
            continuation.yield(.loginSuccess(result: loginResult))
            continuation.yield(.completed(result: loginResult))
            continuation.finish()
            
        } catch {
            Logger.error("SynologyUserLogin#performSessionLogin, session verification failed: \(error)")
            continuation.yield(.failed(error: .audioStationVerificationFailed(message: error.localizedDescription)))
            continuation.finish()
        }
    }
    
    // MARK: - Private Helpers
    
    /// 获取连接地址
    /// Fetch connection URL
    private func fetchConnectionUrl(
        server: String,
        enableHttps: Bool,
        continuation: AsyncStream<LoginProgress>.Continuation
    ) async -> (type: ConnectionType, url: String)? {
        if await !quickConnectApi.isQuickConnectId(server: server) {
            // 自定义域名直接返回
            return (.custom_domain, server)
        }
        
        // QuickConnect 模式，获取设备地址
        continuation.yield(.fetchingQuickConnect)
        
        do {
            if let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(
                quickConnectId: server,
                enableHttps: enableHttps
            ) {
                continuation.yield(.quickConnectFetched(type: connection.type, url: connection.url))
                return (connection.type, connection.url)
            }
        } catch {
            Logger.error("SynologyUserLogin#fetchConnectionUrl, error: \(error)")
        }
        
        return nil
    }
}
