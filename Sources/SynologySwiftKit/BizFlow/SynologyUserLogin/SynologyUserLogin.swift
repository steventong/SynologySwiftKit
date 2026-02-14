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
    private let pingpong: PingPongProviding
    private let audioStationApi: AudioStationApi

    // MARK: - Initialization

    /// 初始化登录管理器
    /// Initialize login manager
    /// - Parameters:
    ///   - deviceConnection: 设备连接提供者 / Device connection provider
    ///   - apiInfoApi: API 信息提供者 / API info provider
    ///   - apiClient: API 客户端 / API client
    ///   - pingpong: PingPong 服务 / PingPong service
    public init(deviceConnection: DeviceConnectionProviding, apiInfoApi: ApiInfoProviding, apiClient: ApiClientProviding, pingpong: PingPongProviding) {
        self.deviceConnection = deviceConnection
        self.apiInfoApi = apiInfoApi
        self.pingpong = pingpong

        quickConnectApi = QuickConnectApi(deviceConnection: deviceConnection,
                                          apiClient: apiClient,
                                          pingpong: pingpong)
        authApi = AuthApi(apiClient: apiClient, deviceConnection: deviceConnection)
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
    ///   - shouldSavePassword: 是否保存密码（默认为 true）
    /// - Returns: AsyncStream 返回登录进度
    public func login(server: String, enableHttps: Bool, username: String, password: String, otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<LoginProgress> {
        AsyncStream { continuation in
            Task {
                await self.performPasswordLogin(server: server, enableHttps: enableHttps, username: username, password: password, otpCode: otpCode, shouldSavePassword: shouldSavePassword, continuation: continuation)
            }
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
    public func login(server: String, enableHttps: Bool, username: String, sid: String, did: String?) -> AsyncStream<LoginProgress> {
        AsyncStream { continuation in
            Task {
                await self.performSessionLogin(server: server, enableHttps: enableHttps, username: username, sid: sid, did: did, continuation: continuation)
            }
        }
    }
}

// MARK: - Private Support

private extension SynologyUserLogin {
    /// 执行密码登录
    /// Perform password login
    func performPasswordLogin(server: String, enableHttps: Bool, username: String, password: String, otpCode: String?, shouldSavePassword: Bool,
                              continuation: AsyncStream<LoginProgress>.Continuation) async {
        continuation.yield(.connecting)

        // 保存登录偏好设置
        await deviceConnection.updateLoginPreferences(server: server, isEnableHttps: enableHttps)

        // 获取连接地址
        // Fetch connection URL
        guard let connection = await fetchConnectionUrl(server: server, enableHttps: enableHttps) else {
            continuation.yield(.failed(message: SynologyError.connection(.unavailable).localizedDescription))
            continuation.finish()
            return
        }

        // 保存可用地址
        await deviceConnection.updateCurrentConnectionUrl(type: connection.type, url: connection.url)

        // 确定服务器类型
        let isQuickConnectID = await quickConnectApi.isQuickConnectId(server: server)
        let serverType: ServerType = isQuickConnectID ? .quickConnectId : .customDomain

        // 更新 API 信息 + 认证
        // Update API info + authenticate
        continuation.yield(.authenticating)

        do {
            _ = try await apiInfoApi.checkSynologyApiInfo(cacheEnabled: false, updateCache: true)
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, API info fetch failed: \(error)")
            continuation.yield(.failed(message: SynologyError.network(.requestFailed(message: error.localizedDescription)).localizedDescription))
            continuation.finish()
            return
        }

        do {
            let authResult = try await authApi.userLogin(server: connection.url, username: username, password: password, otpCode: otpCode)

            // 登录成功，保存会话
            // Login succeeded, save session
            await deviceConnection.updateLoginSession(username: username, sid: authResult.sid, did: authResult.did)

            // 登录成功，根据用户选择保存或清除凭据
            // Login succeeded, save or remove credentials based on user choice
            if shouldSavePassword {
                await deviceConnection.saveCredentials(server: server, username: username, password: password)
            } else {
                await deviceConnection.removeCredentials()
            }

            Logger.info("SynologyUserLogin#performPasswordLogin, result: \(authResult)")

            // 验证 AudioStation
            // Verify AudioStation
            let audioStationInfo = try await audioStationApi.info.query()
            Logger.info("SynologyUserLogin#performPasswordLogin, audioStationInfo: \(audioStationInfo)")

            let loginResult = LoginResult(sid: authResult.sid, did: authResult.did, connectionType: connection.type, connectionUrl: connection.url, serverType: serverType)
            continuation.yield(.completed(result: loginResult))
            continuation.finish()

        } catch let error as SynologyError where error.isOtpRequired {
            // 需要 OTP 验证码（不算失败，需要用户输入）
            // OTP required (not a failure, user input needed)
            Logger.info("SynologyUserLogin#performPasswordLogin, OTP required")
            continuation.yield(.otpRequired)
            continuation.finish()
        } catch {
            Logger.error("SynologyUserLogin#performPasswordLogin, auth failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
        }
    }

    /// 执行 Session 登录
    /// Perform session login
    func performSessionLogin(
        server: String,
        enableHttps: Bool,
        username: String,
        sid: String,
        did: String?,
        continuation: AsyncStream<LoginProgress>.Continuation
    ) async {
        continuation.yield(.connecting)

        // 保存登录偏好设置
        await deviceConnection.updateLoginPreferences(server: server, isEnableHttps: enableHttps)

        // 获取连接地址（优先使用保存的地址）
        // Fetch connection URL (prefer saved address)
        guard let connection = await fetchConnectionUrlWithCachedPriority(
            server: server,
            enableHttps: enableHttps
        ) else {
            continuation.yield(.failed(message: SynologyError.connection(.unavailable).localizedDescription))
            continuation.finish()
            return
        }

        // 保存可用地址
        await deviceConnection.updateCurrentConnectionUrl(type: connection.type, url: connection.url)

        // 确定服务器类型
        let isQuickConnectID = await quickConnectApi.isQuickConnectId(server: server)
        let serverType: ServerType = isQuickConnectID ? .quickConnectId : .customDomain

        // 更新 API 信息 + 验证会话
        // Update API info + verify session
        continuation.yield(.authenticating)

        do {
            _ = try await apiInfoApi.checkSynologyApiInfo(cacheEnabled: false, updateCache: true)
        } catch {
            Logger.error("SynologyUserLogin#performSessionLogin, API info fetch failed: \(error)")
            // 如果连 API Info 都获取失败，说明不仅仅是 Session 失效，可能是网络或服务问题
            // 但也有可能仅仅是 Session 失效导致 API 访问被拒？通常 API Info 不需要 Session
            // 这里为了保险，暂不自动重登，直接报错
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
            return
        }

        do {
            // 通过查询 AudioStation 验证会话
            // Verify session by querying AudioStation
            let audioStationInfo = try await audioStationApi.info.query(sid: sid, did: did)

            // 登录成功，保存会话
            // Login succeeded, save session
            await deviceConnection.updateLoginSession(username: username, sid: sid, did: did)

            Logger.info("SynologyUserLogin#performSessionLogin, audioStationInfo: \(audioStationInfo)")

            let loginResult = LoginResult(
                sid: sid,
                did: did,
                connectionType: connection.type,
                connectionUrl: connection.url,
                serverType: serverType
            )

            continuation.yield(.completed(result: loginResult))
            continuation.finish()

        } catch {
            Logger.warn("SynologyUserLogin#performSessionLogin, session verification failed: \(error)")

            // Session 失效，尝试使用保存的凭据自动重登
            // Session expired, try auto re-login with saved credentials
            if let credentials = await deviceConnection.getCredentials(), credentials.server == server, credentials.username == username {
                Logger.info("SynologyUserLogin#performSessionLogin, attempting auto re-login with saved credentials")

                await performPasswordLogin(server: server,
                                           enableHttps: enableHttps,
                                           username: username,
                                           password: credentials.password,

                                           otpCode: nil,
                                           shouldSavePassword: true, // 自动重登意味着之前用户选择保存了密码，所以继续保存
                                           continuation: continuation
                )
                return
            }

            // 无凭据或不匹配，由用户手动登录
            // No credentials or mismatch, manual login required
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
        }
    }

    /// 获取连接地址（直接通过 QuickConnect 查找）
    /// Fetch connection URL (directly via QuickConnect)
    func fetchConnectionUrl(server: String, enableHttps: Bool) async -> (type: ConnectionType, url: String)? {
        if await !quickConnectApi.isQuickConnectId(server: server) {
            // 自定义域名直接返回
            return (.custom_domain, server)
        }

        // QuickConnect 模式，获取设备地址
        // QuickConnect mode, fetch device address
        do {
            let connection = try await quickConnectApi.getDeviceConnectionByQuickConnectId(quickConnectId: server, enableHttps: enableHttps)
            return (connection.type, connection.url)
        } catch {
            Logger.error("SynologyUserLogin#fetchConnectionUrl, error: \(error)")
        }

        return nil
    }

    /// 获取连接地址（优先使用已保存的地址，不可达时再通过 QuickConnect 重新查找）
    /// Fetch connection URL with cached address priority.
    /// First tries the saved connection URL; falls back to QuickConnect if unreachable.
    func fetchConnectionUrlWithCachedPriority(server: String, enableHttps: Bool) async -> (type: ConnectionType, url: String)? {
        // 检查已保存的连接地址
        // Check saved connection URL
        if let savedConnection = await deviceConnection.getCurrentConnectionUrl() {
            Logger.info("SynologyUserLogin#fetchConnectionUrlWithCachedPriority, checking saved connection: \(savedConnection)")

            let pingOK = await pingpong.pingpong(url: savedConnection.url)
            if pingOK {
                Logger.info("SynologyUserLogin#fetchConnectionUrlWithCachedPriority, saved connection is reachable")
                return (savedConnection.type, savedConnection.url)
            }

            // 已保存地址不可达
            // Saved connection is unreachable
            Logger.warn("SynologyUserLogin#fetchConnectionUrlWithCachedPriority, saved connection unreachable: \(savedConnection.url)")

            // 自定义域名不可达，不回退 QuickConnect
            // Custom domain unreachable, do not fallback to QuickConnect
            if savedConnection.type == .custom_domain {
                return nil
            }
        }

        // 回退到 QuickConnect 查找
        // Fallback to QuickConnect lookup
        return await fetchConnectionUrl(server: server, enableHttps: enableHttps)
    }
}
