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

    private let keychainStorage: KeychainStorage
    private let apiInfoApi: ApiInfoProviding
    private let quickConnectApi: QuickConnectApi
    private let authApi: AuthApi
    private let pingpong: PingPongProviding
    private let audioStationApi: AudioStationApi
    private let apiClient: ApiClientProviding

    // MARK: - Initialization

    /// 初始化登录管理器
    /// Initialize login manager
    /// - Parameters:
    ///   - keychainStorage: Keychain 存储 / Keychain Storage
    ///   - apiInfoApi: API 信息提供者 / API info provider
    ///   - apiClient: API 客户端 / API client
    ///   - pingpong: PingPong 服务 / PingPong service
    public init(keychainStorage: KeychainStorage = KeychainStorage(),
                apiInfoApi: ApiInfoProviding,
                apiClient: ApiClientProviding,
                pingpong: PingPongProviding) {
        self.keychainStorage = keychainStorage
        self.apiInfoApi = apiInfoApi
        self.apiClient = apiClient
        self.pingpong = pingpong

        quickConnectApi = QuickConnectApi(apiClient: apiClient, pingpong: pingpong)

        authApi = AuthApi(apiClient: apiClient, keychainStorage: keychainStorage)
        audioStationApi = AudioStationApi(apiClient: apiClient)
    }

    /// 通过密码登录（AsyncStream 版本）
    /// Login with password (AsyncStream version)
    /// - Parameters:
    ///   - server: QuickConnect ID 或自定义域名
    ///   - enableHttps: 是否启用 HTTPS
    ///   - username: 用户名
    ///   - password: 密码
    ///   - otpCode: 可选的 OTP 代码
    ///   - shouldSavePassword: 是否保存密码（默认为 true）
    /// - Returns: AsyncStream 返回登录进度
    public func login(server: String, enableHttps: Bool, username: String, password: String, otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            Task {
                await self.performPasswordLogin(server: server,
                                                enableHttps: enableHttps,
                                                username: username,
                                                password: password,
                                                otpCode: otpCode,
                                                shouldSavePassword: shouldSavePassword,
                                                continuation: continuation)
            }
        }
    }
}

// MARK: - Private Support

private extension SynologyUserLogin {
    /// 执行密码登录
    /// Perform password login
    func performPasswordLogin(server: String, enableHttps: Bool, username: String, password: String, otpCode: String?, shouldSavePassword: Bool, continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) async {
        continuation.yield(.connecting)

        // 解析可用连接 (使用 CheckDeviceConnection)
        // Resolve available connection (using CheckDeviceConnection)
        let connection: (type: ConnectionType, url: String)

        do {
            // 临时实例化 CheckDeviceConnection (Temporary instantiation of CheckDeviceConnection)
            let connectionChecker = CheckDeviceConnection(apiClient: apiClient, apiInfoApi: apiInfoApi, quickConnectApi: quickConnectApi, pingpong: pingpong, audioStationApi: audioStationApi)
            connection = try await connectionChecker.resolveAvailableConnection(server: server, enableHttps: enableHttps, verifySid: false)
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, connection resolution failed: \(error)")
            continuation.yield(.failed(message: SynologyError.network(message: error.localizedDescription).localizedDescription))
            continuation.finish()
            return
        }

        // 更新 ApiClient 连接状态 (Update ApiClient connection status)
        apiClient.updateConnection(type: connection.type, url: connection.url)

        // 保存可用地址 (Save available address to Keychain)
        keychainStorage.saveConnectionInfo(url: connection.url, typeString: connection.type.rawValue)

        // 确定服务器类型
        let isQuickConnectID = QuickConnectUtils.isQuickConnectId(server: server)
        let serverType: ServerType = isQuickConnectID ? .quickConnectId : .customDomain

        // 更新 API 信息 + 认证
        // Update API info + authenticate
        continuation.yield(.authenticating)

        do {
            _ = try await apiInfoApi.checkSynologyApiInfo(cacheEnabled: false, updateCache: true)
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, API info fetch failed: \(error)")
            continuation.yield(.failed(message: SynologyError.network(message: error.localizedDescription).localizedDescription))
            continuation.finish()
            return
        }

        // 根据用户选择保存或清除凭据
        // save or remove credentials based on user choice
        if shouldSavePassword {
            keychainStorage.saveCredentials(server: server, username: username, password: password, isEnableHttps: enableHttps)
        } else {
            keychainStorage.removeCredentials()
        }

        do {
            // 获取持久化设备信息
            let authResult = try await authApi.userLogin(server: connection.url, username: username, password: password, otpCode: otpCode)

            // 登录成功，保存会话
            // Login succeeded, save session
            apiClient.updateSession(sid: authResult.sid, did: authResult.did)

            Logger.info("SynologyUserLogin#performPasswordLogin, result: \(authResult)")

//            // 验证 sid
//            let audioStationInfo = try await audioStationApi.info.query()
//            Logger.info("SynologyUserLogin#performPasswordLogin, audioStationInfo: \(audioStationInfo)")

            let loginResult = SynologyUserLoginResult(sid: authResult.sid, did: authResult.did, connectionType: connection.type, connectionUrl: connection.url, serverType: serverType)

            continuation.yield(.completed(result: loginResult))
            continuation.finish()
        } catch let SynologyError.auth(code, msg) where code == 403 {
            // 需要 OTP 验证码（不算失败，需要用户输入）
            // OTP required (not a failure, user input needed)
            Logger.info("SynologyUserLogin#performPasswordLogin, OTP required, message: \(msg)")
            continuation.yield(.otpRequired)
            continuation.finish()
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, auth failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
        }
    }
}
