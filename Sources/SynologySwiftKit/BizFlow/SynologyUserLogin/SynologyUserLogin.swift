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
    private let apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating
    private let connectionChecker: any ConnectionChecking
    private let keyChainStorage: any SensitiveStorage

    // MARK: - Initialization

    /// 初始化登录管理器
    /// Initialize login manager
    /// - Parameters:
    ///   - keyChainStorage: Keychain 存储 / Keychain Storage
    ///   - apiInfoApi: API 信息提供者 / API info provider
    ///   - apiClient: API 客户端 / API client
    init(apiInfoApi: ApiInfoProviding,
         apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating,
         authApi: AuthClient,
         audioStationApi: AudioStationClient,
         connectionChecker: any ConnectionChecking,
         keyChainStorage: any SensitiveStorage = StorageService()) {
        self.apiInfoApi = apiInfoApi
        self.apiClient = apiClient
        self.authApi = authApi
        self.audioStationApi = audioStationApi
        self.connectionChecker = connectionChecker
        self.keyChainStorage = keyChainStorage
    }

    /// 通过密码登录（AsyncStream 版本）
    /// Login with password (AsyncStream version)
    func login(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            let task = Task {
                Logger.info("SynologyUserLogin#login(password), entry, server=\(server), usesHTTPS=\(usesHTTPS), hasOtp=\(otpCode != nil)")
                await self.performPasswordLogin(server: server, usesHTTPS: usesHTTPS, username: username, password: password, otpCode: otpCode, shouldSavePassword: shouldSavePassword, fetchApiList: true, attemptSliceLogin: false, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 刷新登录信息，静默恢复（优先尝试 slice 登录命中缓存 SID，失败时自动 fallback 到全量登录）
    /// Silent resume: try slice login (validates cached SID); on failure fall back to full password login.
    func login() -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            let task = Task {
                guard let credentials = keyChainStorage.getCredentials() else {
                    Logger.warn("SynologyUserLogin#login(resume), abort: no saved credentials")
                    continuation.yield(.invalidSession(message: "No saved credentials found"))
                    continuation.finish()
                    return
                }

                Logger.info("SynologyUserLogin#login(resume), entry, server=\(credentials.server), usesHTTPS=\(credentials.usesHTTPS), strategy=sliceThenFull")

                await self.performPasswordLogin(
                    server: credentials.server,
                    usesHTTPS: credentials.usesHTTPS,
                    username: credentials.username,
                    password: credentials.password,
                    otpCode: nil,
                    shouldSavePassword: true,
                    fetchApiList: true,
                    attemptSliceLogin: true,
                    continuation: continuation
                )
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 使用保存的凭据强制执行全量登录（跳过 slice 优化）
    /// Force full password re-login using saved credentials (skips slice optimization).
    ///
    /// 用于已知缓存 SID 失效的恢复路径（例如 SessionOrchestrator 检测到 session fault 之后），
    /// 避免在已知一定失败的场景下浪费一次 slice 校验的 round-trip。
    func relogin() -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            let task = Task {
                guard let credentials = keyChainStorage.getCredentials() else {
                    Logger.warn("SynologyUserLogin#login(relogin), abort: no saved credentials")
                    continuation.yield(.invalidSession(message: "No saved credentials found"))
                    continuation.finish()
                    return
                }

                Logger.info("SynologyUserLogin#login(relogin), entry, server=\(credentials.server), usesHTTPS=\(credentials.usesHTTPS), strategy=forceFull")

                await self.performPasswordLogin(
                    server: credentials.server,
                    usesHTTPS: credentials.usesHTTPS,
                    username: credentials.username,
                    password: credentials.password,
                    otpCode: nil,
                    shouldSavePassword: true,
                    fetchApiList: true,
                    attemptSliceLogin: false,
                    continuation: continuation
                )
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Private Support

private extension SynologyUserLogin {
    /// 执行密码登录，可选先尝试 slice 校验缓存 SID。
    /// Perform password login, optionally trying to validate cached SID first (slice optimization).
    ///
    /// 流程：
    /// 1. 解析连接地址（connectionChecker）
    /// 2. 刷新 API 列表（apiInfoApi.refresh）
    /// 3. 若 attemptSliceLogin && usedCachedConnection && 有缓存 SID：调用 AudioStation.Info.query
    ///    - 成功 → 直接返回 .completed（缓存 SID 可用，无需 round-trip 到 Auth）
    ///    - 失败 → 仅记录日志后 fall through 到全量登录（不再抛 .invalidSession）
    /// 4. 调用 authApi.login(...) 拿到新 SID
    func performPasswordLogin(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String?, shouldSavePassword: Bool, fetchApiList: Bool = true, attemptSliceLogin: Bool = false, continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) async {
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

        // 解析可用连接 (使用 ConnectionChecker)
        // Resolve available connection (using ConnectionChecker)
        let connection: SynologyConnection
        let usedCachedConnection: Bool

        do {
            var resolvedConnection: SynologyConnection?
            var resolvedFromCache = false
            for await progress in connectionChecker.check(server: server, usesHTTPS: usesHTTPS) {
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
                    Logger.warn("SynologyUserLogin#performPasswordLogin, connection check failed: \(message)")
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

        let previousConnection = currentConnection()
        let previousSession = apiClient.session ?? keyChainStorage.getSessionInfo()
        apiClient.updateConnection(type: connection.type, url: connection.url)

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
            rollbackConnection(to: previousConnection)
            continuation.finish()
            return
        } catch {
            rollbackConnection(to: previousConnection)
            Logger.error("SynologyUserLogin#performPasswordLogin, API info fetch failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
            return
        }

        // Step 1: 可选 slice 登录尝试（命中缓存 SID 即可直接返回，失败不影响后续全量登录）
        if attemptSliceLogin {
            let sliceOutcome = await attemptSliceValidation(
                connection: connection,
                serverType: serverType,
                usedCachedConnection: usedCachedConnection,
                continuation: continuation
            )

            switch sliceOutcome {
            case .completed:
                // slice 命中：performPasswordLogin 已完成
                return
            case .skipped(let reason):
                Logger.info("SynologyUserLogin#performPasswordLogin, slice skipped, reason=\(reason), proceeding to full login")
            case .failed(let reason):
                Logger.warn("SynologyUserLogin#performPasswordLogin, slice failed, reason=\(reason), proceeding to full login")
                // slice 校验失败说明缓存 SID 不可用，清掉后续 authApi.login 用不到的脏 cookie
                apiClient.clearSession()
            }
        }

        // Step 2: 全量密码登录
        do {
            try Task.checkCancellation()

            let authResult = try await authApi.login(username: username, password: password, otpCode: otpCode)
            try Task.checkCancellation()

            // 登录成功，保存会话
            // Login succeeded, save session
            apiClient.updateSession(sid: authResult.sid, did: authResult.did)
            keyChainStorage.saveSessionInfo(sid: authResult.sid, did: authResult.did)
            saveConnection(url: connection.url, type: connection.type)

            Logger.info("SynologyUserLogin#performPasswordLogin, full login success, didExists=\(authResult.did != nil)")
            let loginResult = SynologyUserLoginResult(
                session: SynologySession(sid: authResult.sid, did: authResult.did),
                connection: connection,
                serverType: serverType
            )

            continuation.yield(.completed(result: loginResult))
            continuation.finish()
        } catch let SynologyError.auth(code, msg) where code == 403 {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            // 需要 OTP 验证码（不算失败，需要用户输入）
            // OTP required (not a failure, user input needed)
            Logger.info("SynologyUserLogin#performPasswordLogin, OTP required, message: \(msg)")
            continuation.yield(.otpRequired)
            continuation.finish()
        } catch let SynologyError.sessionExpired(code, msg) {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            // 这里是真信号：凭据登录本身被拒绝（不是 slice 校验失败被误传上来的）。
            Logger.warn("SynologyUserLogin#performPasswordLogin, full login invalidSession, code=\(code), msg=\(msg)")
            continuation.yield(.invalidSession(message: "session expired"))
            continuation.finish()
        } catch is CancellationError {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            continuation.finish()
        } catch {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            Logger.error("SynologyUserLogin#performPasswordLogin, full login failed: \(error)")
            continuation.yield(.failed(message: error.localizedDescription))
            continuation.finish()
        }
    }

    /// slice 登录尝试的结果
    /// Outcome of a slice-login attempt.
    enum SliceLoginOutcome {
        /// 缓存 SID 校验通过，已经 yield .completed
        case completed
        /// 不具备 slice 前提条件（未命中缓存连接 / 无缓存 SID），未做任何远端调用
        case skipped(reason: String)
        /// 远端校验失败（缓存 SID 已失效或网络错误），未 yield 任何状态
        case failed(reason: String)
    }

    /// 尝试用缓存 SID 命中 AudioStation.Info；任何失败都 swallowed，调用方继续走全量登录。
    /// Attempt to validate cached SID against AudioStation.Info. All failures are swallowed so the
    /// caller can fall back to a full password login.
    func attemptSliceValidation(connection: SynologyConnection,
                                serverType: ServerType,
                                usedCachedConnection: Bool,
                                continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) async -> SliceLoginOutcome {
        guard usedCachedConnection else {
            return .skipped(reason: "connection_not_cached")
        }
        guard let sessionInfo = keyChainStorage.getSessionInfo() else {
            return .skipped(reason: "no_cached_session")
        }

        Logger.info("SynologyUserLogin#attemptSliceValidation, start, sid=\(Logger.maskedSessionValue(sessionInfo.sid))")

        do {
            _ = try await audioStationApi.info.query()
            try Task.checkCancellation()

            // slice 命中：缓存 SID 仍然有效，直接构造结果
            let loginResult = SynologyUserLoginResult(
                session: SynologySession(sid: sessionInfo.sid, did: sessionInfo.did),
                connection: connection,
                serverType: serverType
            )
            saveConnection(url: connection.url, type: connection.type)

            Logger.info("SynologyUserLogin#attemptSliceValidation, hit, sid=\(Logger.maskedSessionValue(sessionInfo.sid))")
            continuation.yield(.completed(result: loginResult))
            continuation.finish()
            return .completed
        } catch let SynologyError.sessionExpired(code, msg) {
            return .failed(reason: "sessionExpired(code=\(code), msg=\(msg))")
        } catch is CancellationError {
            // 取消由上层处理；当作 failed 让 caller 退出
            return .failed(reason: "cancelled")
        } catch {
            return .failed(reason: "error(\(error.localizedDescription))")
        }
    }

    func currentConnection() -> SynologyConnection? {
        if let connection = apiClient.connection {
            return SynologyConnection(type: connection.type, url: connection.url)
        }

        guard let persisted = keyChainStorage.getConnectionInfo(),
              let type = ConnectionType(rawValue: persisted.typeString)
        else {
            return nil
        }

        return SynologyConnection(type: type, url: persisted.url)
    }

    func saveConnection(url: String, type: ConnectionType) {
        apiClient.updateConnection(type: type, url: url)
        keyChainStorage.saveConnectionInfo(url: url, typeString: type.rawValue)
    }

    func rollbackConnection(to connection: SynologyConnection?) {
        guard let connection else {
            return
        }

        apiClient.updateConnection(type: connection.type, url: connection.url)
    }

    func rollbackSession(to session: (sid: String, did: String?)?) {
        guard let session else {
            apiClient.clearSession()
            return
        }

        apiClient.updateSession(sid: session.sid, did: session.did)
    }
}
