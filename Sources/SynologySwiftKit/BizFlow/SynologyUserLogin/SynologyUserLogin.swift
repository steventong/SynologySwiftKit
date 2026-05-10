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
final class SynologyUserLogin: SynologyUserLoginProviding {
    // MARK: - Dependencies

    private let apiInfoApi: ApiInfoProviding
    private let authApi: AuthClient
    private let audioStationApi: AudioStationClient
    private let apiClient: ConnectionStateUpdating & SessionStateUpdating
    private let connectionChecker: CheckDeviceConnectionProviding
    private let keyChainStorage: any SensitiveStorage

    // MARK: - Initialization

    /// 初始化登录管理器
    /// Initialize login manager
    /// - Parameters:
    ///   - keyChainStorage: Keychain 存储 / Keychain Storage
    ///   - apiInfoApi: API 信息提供者 / API info provider
    ///   - apiClient: API 客户端 / API client
    init(apiInfoApi: ApiInfoProviding,
         apiClient: ConnectionStateUpdating & SessionStateUpdating,
         authApi: AuthClient,
         audioStationApi: AudioStationClient,
         connectionChecker: CheckDeviceConnectionProviding,
         keyChainStorage: any SensitiveStorage = KeyChainStorage()) {
        self.apiInfoApi = apiInfoApi
        self.apiClient = apiClient
        self.authApi = authApi
        self.audioStationApi = audioStationApi
        self.connectionChecker = connectionChecker
        self.keyChainStorage = keyChainStorage
    }

    /// 通过密码登录（AsyncStream 版本）
    /// Login with password (AsyncStream version)
    /// - Parameters:
    ///   - server: QuickConnect ID 或自定义域名
    ///   - usesHTTPS: 是否启用 HTTPS
    ///   - username: 用户名
    ///   - password: 密码
    ///   - otpCode: 可选的 OTP 代码
    ///   - shouldSavePassword: 是否保存密码（默认为 true）
    /// - Returns: AsyncStream 返回登录进度
    func login(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            let task = Task {
                await self.performPasswordLogin(server: server, usesHTTPS: usesHTTPS, username: username, password: password, otpCode: otpCode, shouldSavePassword: shouldSavePassword, fetchApiList: true, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 刷新登录信息，静默登录
    func login() -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            let task = Task {
                guard let credentials = keyChainStorage.getCredentials() else {
                    Logger.warn("SynologyUserLogin#login(auto-full), no saved credentials found")
                    continuation.yield(.invalidSession(message: "No saved credentials found"))
                    continuation.finish()
                    return
                }

                let server = credentials.server
                let usesHTTPS = credentials.usesHTTPS
                let username = credentials.username
                let password = credentials.password

                // set sliceLogin: true
                await self.performPasswordLogin(server: server, usesHTTPS: usesHTTPS, username: username, password: password, otpCode: nil, shouldSavePassword: true, fetchApiList: true, sliceLogin: true, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Private Support

private extension SynologyUserLogin {
    /// 执行密码登录
    /// Perform password login
    func performPasswordLogin(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String?, shouldSavePassword: Bool, fetchApiList: Bool = true, sliceLogin: Bool = false, continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) async {
        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        // 连接检查
        continuation.yield(.connecting)

        // 确定服务器类型
        let isQuickConnectID = QuickConnectUtils.isQuickConnectId(server: server)
        let serverType: ServerType = isQuickConnectID ? .quickConnectId : .customDomain

        // 根据用户选择保存或清除凭据
        // save or remove credentials based on user choice
        if shouldSavePassword {
            keyChainStorage.saveCredentials(server: server, username: username, password: password, usesHTTPS: usesHTTPS)
        } else {
            keyChainStorage.removeCredentials()
        }

        // 解析可用连接 (使用 CheckDeviceConnection)
        // Resolve available connection (using CheckDeviceConnection)
        let connection: SynologyConnection
        let usedCachedConnection: Bool

        do {
            var resolvedConnection: SynologyConnection?
            var resolvedFromCache = false
            for await progress in connectionChecker.checkConnectionStatus(server: server, usesHTTPS: usesHTTPS) {
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }

                switch progress {
                case .checking:
                    break
                case let .success(connection, usedCachedConnection):
                    resolvedConnection = connection
                    resolvedFromCache = usedCachedConnection
                case let .failed(message):
                    Logger.warn("SynologyUserLogin#performPasswordLogin, checkConnectionStatus failed: \(message)")
                }
            }

            guard let resolvedConnection else {
                throw SynologyError.network(message: "Connection resolution failed")
            }

            connection = resolvedConnection
            usedCachedConnection = resolvedFromCache
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, connection resolution failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
            return
        }

        guard !Task.isCancelled else {
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
                try await apiInfoApi.refresh()
            }
            try Task.checkCancellation()
        } catch is CancellationError {
            continuation.finish()
            return
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, API info fetch failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
            return
        }

        do {
            try Task.checkCancellation()

            if sliceLogin && usedCachedConnection,
               let sessionInfo = keyChainStorage.getSessionInfo()
            {
                // 静默登录且没有更换连接地址时，必须验证缓存 SID 仍然可用。
                _ = try await audioStationApi.info.query()
                try Task.checkCancellation()

                let loginResult = SynologyUserLoginResult(
                    session: SynologySession(sid: sessionInfo.sid, did: sessionInfo.did),
                    connection: connection,
                    serverType: serverType
                )
                continuation.yield(.completed(result: loginResult))
                continuation.finish()
                return
            }

            let authResult = try await authApi.login(username: username, password: password, otpCode: otpCode)
            try Task.checkCancellation()

            // 登录成功，保存会话
            // Login succeeded, save session
            apiClient.updateSession(sid: authResult.sid, did: authResult.did)
            keyChainStorage.saveSessionInfo(sid: authResult.sid, did: authResult.did)

            Logger.info("SynologyUserLogin#performPasswordLogin, result: \(authResult)")
            let loginResult = SynologyUserLoginResult(
                session: SynologySession(sid: authResult.sid, did: authResult.did),
                connection: connection,
                serverType: serverType
            )

            continuation.yield(.completed(result: loginResult))
            continuation.finish()
        } catch let SynologyError.auth(code, msg) where code == 403 {
            // 需要 OTP 验证码（不算失败，需要用户输入）
            // OTP required (not a failure, user input needed)
            Logger.info("SynologyUserLogin#performPasswordLogin, OTP required, message: \(msg)")
            continuation.yield(.otpRequired)
            continuation.finish()
        } catch let SynologyError.sessionExpired(code, msg) {
            Logger.info("SynologyUserLogin#performPasswordLogin, invalidSession: \(code), \(msg)")
            continuation.yield(.invalidSession(message: "session expired"))
            continuation.finish()
        } catch is CancellationError {
            continuation.finish()
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, auth failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
        }
    }
}
