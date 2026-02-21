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
public actor SynologyUserLogin: SynologyUserLoginProviding {
    // MARK: - Dependencies

    private let apiInfoApi: ApiInfoProviding
    private let quickConnectApi: QuickConnectApi
    private let authApi: AuthApi
    private let pingpong: PingPongProviding
    private let audioStationApi: AudioStationApi
    private let apiClient: ApiClientProviding
    private let keyChainStorage: KeyChainStorage

    // MARK: - Initialization

    /// 初始化登录管理器
    /// Initialize login manager
    /// - Parameters:
    ///   - keyChainStorage: Keychain 存储 / Keychain Storage
    ///   - apiInfoApi: API 信息提供者 / API info provider
    ///   - apiClient: API 客户端 / API client
    ///   - pingpong: PingPong 服务 / PingPong service
    public init(apiInfoApi: ApiInfoProviding, apiClient: ApiClientProviding, pingpong: PingPongProviding, keyChainStorage: KeyChainStorage = KeyChainStorage()) {
        self.apiInfoApi = apiInfoApi
        self.apiClient = apiClient
        self.pingpong = pingpong
        self.keyChainStorage = keyChainStorage

        quickConnectApi = QuickConnectApi(apiClient: apiClient, pingpong: pingpong)
        authApi = AuthApi(apiClient: apiClient, keyChainStorage: keyChainStorage)
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
    public func login(server: String, enableHttps: Bool,
                      username: String, password: String,
                      otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            Task {
                await self.performPasswordLogin(server: server, enableHttps: enableHttps, username: username, password: password, otpCode: otpCode, shouldSavePassword: shouldSavePassword, fetchApiList: true, continuation: continuation)
            }
        }
    }

    /// 刷新登录信息，静默登录
    public func login(continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            Task {
                guard let credentials = keyChainStorage.getCredentials() else {
                    Logger.warn("SynologyUserLogin#login(auto-full), no saved credentials found")
                    continuation.yield(.failed(message: "No saved credentials found"))
                    continuation.finish()
                    return
                }

                let server = credentials.server
                let enableHttps = credentials.isEnableHttps ?? false
                let username = credentials.username
                let password = credentials.password

                // set sliceLogin: true
                await self.performPasswordLogin(server: server, enableHttps: enableHttps, username: username, password: password, otpCode: nil, shouldSavePassword: true, fetchApiList: true, sliceLogin: true, continuation: continuation)
            }
        }
    }
}

// MARK: - Private Support

private extension SynologyUserLogin {
    /// 执行密码登录
    /// Perform password login
    func performPasswordLogin(server: String, enableHttps: Bool, username: String, password: String, otpCode: String?, shouldSavePassword: Bool, fetchApiList: Bool = true, sliceLogin: Bool = false, continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) async {
        // 连接检查
        continuation.yield(.connecting)

        // 确定服务器类型
        let isQuickConnectID = QuickConnectUtils.isQuickConnectId(server: server)
        let serverType: ServerType = isQuickConnectID ? .quickConnectId : .customDomain

        // 根据用户选择保存或清除凭据
        // save or remove credentials based on user choice
        if shouldSavePassword {
            keyChainStorage.saveCredentials(server: server, username: username, password: password, isEnableHttps: enableHttps)
        } else {
            keyChainStorage.saveCredentials(server: server, username: username, password: "", isEnableHttps: enableHttps)
        }

        // 解析可用连接 (使用 CheckDeviceConnection)
        // Resolve available connection (using CheckDeviceConnection)
        let connection: (type: ConnectionType, url: String, cached: Bool)

        do {
            // 实例化 CheckDeviceConnection (Temporary instantiation of CheckDeviceConnection)
            let connectionChecker: CheckDeviceConnectionProviding = CheckDeviceConnection(apiClient: apiClient, apiInfoApi: apiInfoApi, quickConnectApi: quickConnectApi, audioStationApi: audioStationApi, pingpong: pingpong)
            // Start from checkConnectionStatus (it already resolves connection when needed).
            var connectionFromStatus: (type: ConnectionType, url: String, cached: Bool)?
            for await progress in connectionChecker.checkConnectionStatus(server: server, isHttps: enableHttps) {
                switch progress {
                case .checking:
                    break
                case let .success(type, url, cached):
                    connectionFromStatus = (type, url, cached)
                case let .failed(message):
                    Logger.warn("SynologyUserLogin#performPasswordLogin, checkConnectionStatus failed: \(message)")
                }
            }

            guard let connectionFromStatus else {
                throw SynologyError.network(message: "Connection resolution failed")
            }

            connection = connectionFromStatus
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, connection resolution failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
            return
        }

        // 更新 ApiClient 连接状态 (Update ApiClient connection status)
        apiClient.updateConnection(type: connection.type, url: connection.url)
        // 保存可用地址 (Save available address to Keychain)
        keyChainStorage.saveConnectionInfo(url: connection.url, typeString: connection.type.rawValue)

        // 更新 API 信息 + 认证
        // Update API info + authenticate
        continuation.yield(.authenticating)

        do {
            // 刷新 Api 列表
            if fetchApiList {
                _ = try await apiInfoApi.checkSynologyApiInfo(cacheEnabled: false, updateCache: true)
            }
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, API info fetch failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
            return
        }

        do {
            if sliceLogin && connection.cached {
                // 静默登录且没有更换地址,调用接口验证SID是否过期。

                if let sessionInfo = keyChainStorage.getSessionInfo() {
                    _ = try? await audioStationApi.info.query()

                    let loginResult = SynologyUserLoginResult(sid: sessionInfo.sid, did: sessionInfo.did, connectionType: connection.type, connectionUrl: connection.url, serverType: serverType)
                    continuation.yield(.completed(result: loginResult))
                    continuation.finish()
                }
            } else {
                let authResult = try await authApi.userLogin(username: username, password: password, otpCode: otpCode)

                // 登录成功，保存会话
                // Login succeeded, save session
                apiClient.updateSession(sid: authResult.sid, did: authResult.did)
                keyChainStorage.saveSessionInfo(sid: authResult.sid, did: authResult.did)

                Logger.info("SynologyUserLogin#performPasswordLogin, result: \(authResult)")
                let loginResult = SynologyUserLoginResult(sid: authResult.sid, did: authResult.did, connectionType: connection.type, connectionUrl: connection.url, serverType: serverType)

                continuation.yield(.completed(result: loginResult))
                continuation.finish()
            }
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
