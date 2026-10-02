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

    private let sessionOperations: SessionOperationCoordinator
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
         keyChainStorage: any SensitiveStorage = StorageService(),
         sessionOperations: SessionOperationCoordinator = SessionOperationCoordinator()) {
        self.sessionOperations = sessionOperations
        self.apiInfoApi = apiInfoApi
        self.apiClient = apiClient
        self.authApi = authApi
        self.audioStationApi = audioStationApi
        self.connectionChecker = connectionChecker
        self.keyChainStorage = keyChainStorage
    }

    /// 通过密码登录（AsyncStream 版本）
    /// Login with password (AsyncStream version)
    func login(server: String, username: String, password: String, otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            let task = sessionOperations.start { [self] in
                Logger.info("SynologyUserLogin#login(password), entry, server=\(server), protocol=automatic, hasOtp=\(otpCode != nil)")
                await self.performPasswordLogin(server: server, usesHTTPS: nil, username: username, password: password, otpCode: otpCode, shouldSavePassword: shouldSavePassword, fetchApiList: true, attemptSliceLogin: false, continuation: continuation)
            }
            let completion = Task {
                _ = try? await task.value
                continuation.finish()
            }
            continuation.onTermination = { termination in
                // 正常完成不取消生产任务，避免成功保存新地址后被误当作取消回滚。
                if case .cancelled = termination {
                    task.cancel()
                    completion.cancel()
                }
            }
        }
    }

    /// 静默恢复时优先复用原 SID；仅无 SID 或服务器明确判定会话失效才执行全量登录。
    /// 网络、解码与取消只结束本次恢复，保留会话供网络恢复后重试。
    func login() -> AsyncStream<SynologyUserLoginProgress> {
        AsyncStream { continuation in
            let task = sessionOperations.start { [self] in
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
            let completion = Task {
                _ = try? await task.value
                continuation.finish()
            }
            continuation.onTermination = { termination in
                // 正常完成不取消生产任务，避免成功保存新地址后被误当作取消回滚。
                if case .cancelled = termination {
                    task.cancel()
                    completion.cancel()
                }
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
            let task = sessionOperations.start { [self] in
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
                    isSessionRenewal: true,
                    continuation: continuation
                )
            }
            let completion = Task {
                _ = try? await task.value
                continuation.finish()
            }
            continuation.onTermination = { termination in
                // 正常完成不取消生产任务，避免成功保存新地址后被误当作取消回滚。
                if case .cancelled = termination {
                    task.cancel()
                    completion.cancel()
                }
            }
        }
    }
}

// MARK: - Private Support

private extension SynologyUserLogin {
    /// 执行显式密码登录或静默恢复，解析地址并刷新 API 列表后再处理认证。
    /// 静默恢复只要有 SID，就在解析出的地址上校验原会话，不受地址是否命中缓存影响。
    /// 校验成功直接完成；网络故障与取消回滚地址并结束；只有服务器明确失效才清理旧 SID 并全量登录。
    func performPasswordLogin(server: String, usesHTTPS: Bool?, username: String, password: String, otpCode: String?, shouldSavePassword: Bool, fetchApiList: Bool = true, attemptSliceLogin: Bool = false, isSessionRenewal: Bool = false, continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) async {
        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        // 连接检查
        continuation.yield(.connecting)

        // 确定服务器类型
        let isQuickConnectID = QuickConnectUtils.isQuickConnectId(server: server)
        let serverType: ServerType = isQuickConnectID ? .quickConnectId : .customDomain

        // 解析可用连接 (使用 ConnectionChecker)
        // Resolve available connection (using ConnectionChecker)
        let connection: SynologyConnection

        do {
            var resolvedConnection: SynologyConnection?
            let progressStream = if let usesHTTPS {
                connectionChecker.check(server: server, usesHTTPS: usesHTTPS)
            } else {
                connectionChecker.check(server: server)
            }
            for await progress in progressStream {
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }

                switch progress {
                case .checking:
                    break
                case let .success(connection, _):
                    resolvedConnection = connection
                case let .serverCertificateUntrusted(certificate):
                    continuation.yield(.serverCertificateUntrusted(certificate))
                    continuation.finish()
                    return
                case let .failed(message):
                    Logger.warn("SynologyUserLogin#performPasswordLogin, connection check failed: \(message)")
                }
            }

            guard let resolvedConnection else {
                throw SynologyError.network(message: "Connection resolution failed")
            }

            connection = resolvedConnection
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
        do {
            try sessionOperations.commit {
                apiClient.updateConnection(type: connection.type, url: connection.url)
                if attemptSliceLogin, let previousSession {
                    apiClient.updateSession(sid: previousSession.sid, did: previousSession.did)
                }
            }
        } catch { continuation.finish(); return }

        // 更新 API 信息 + 认证
        // Update API info + authenticate
        continuation.yield(.authenticating)

        do {
            // 刷新 Api 列表
            if fetchApiList {
                try await apiInfoApi.refresh()
            }
            try Task.checkCancellation()
        } catch let SynologyError.serverCertificateUntrusted(certificate) {
            rollbackConnection(to: previousConnection)
            continuation.yield(.serverCertificateUntrusted(certificate))
            continuation.finish()
            return
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

        // 记录明确的续期上下文，使服务器拒绝凭据时能结束失效会话，而非不断重试旧 SID。
        var renewingExpiredSession = isSessionRenewal
        // 先校验原 SID；无法确认有效性不等于失效，禁止因弱网进入密码登录。
        if attemptSliceLogin {
            let sliceOutcome = await attemptSliceValidation(
                connection: connection,
                serverType: serverType,
                continuation: continuation
            )

            switch sliceOutcome {
            case .completed:
                // 成功已经提交地址并结束流，不能再因完成后的取消信号回滚。
                return
            case .skipped:
                Logger.info("SynologyUserLogin#performPasswordLogin, no saved SID, proceeding to full login")
            case .invalidSession:
                guard !Task.isCancelled else {
                    rollbackConnection(to: previousConnection)
                    continuation.finish()
                    return
                }
                Logger.info("SynologyUserLogin#performPasswordLogin, server confirmed expired SID, proceeding to full login")
                renewingExpiredSession = true
                do { try sessionOperations.commit { apiClient.clearSession() } }
                catch { continuation.finish(); return }
            case .cancelled:
                rollbackConnection(to: previousConnection)
                continuation.finish()
                return
            case .failed(let error):
                rollbackConnection(to: previousConnection)
                Logger.warn("SynologyUserLogin#performPasswordLogin, slice validation unavailable: \(error)")
                if case let SynologyError.serverCertificateUntrusted(certificate) = error {
                    continuation.yield(.serverCertificateUntrusted(certificate))
                } else {
                    continuation.yield(.failed(message: error.localizedDescription))
                }
                continuation.finish()
                return
            }
        }

        // Step 2: 全量密码登录
        do {
            try Task.checkCancellation()

            let authResult = try await authApi.login(username: username, password: password, otpCode: otpCode)
            try Task.checkCancellation()

            // 登录成功，保存会话
            // Login succeeded, save session
            try sessionOperations.commitState {
                apiClient.updateSession(sid: authResult.sid, did: authResult.did)
                keyChainStorage.saveSessionInfo(sid: authResult.sid, did: authResult.did)
                saveConnection(url: connection.url, type: connection.type)
                commitCredentials(
                    server: server,
                    usesHTTPS: connection.url.lowercased().hasPrefix("https://"),
                    username: username,
                    password: password,
                    shouldSavePassword: shouldSavePassword
                )
            }

            Logger.info("SynologyUserLogin#performPasswordLogin, full login success, didExists=\(authResult.did != nil)")
            let loginResult = SynologyUserLoginResult(
                session: SynologySession(sid: authResult.sid, did: authResult.did),
                connection: connection,
                serverType: serverType
            )

            continuation.yield(.completed(result: loginResult))
            continuation.finish()
        } catch let SynologyError.serverCertificateUntrusted(certificate) {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            continuation.yield(.serverCertificateUntrusted(certificate))
            continuation.finish()
        } catch let SynologyError.auth(code, msg) where code == 403 || code == 404 {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            // 需要或需重新输入 OTP 验证码（不算终止失败，需要用户输入）
            // OTP required or invalid (not a terminal failure; prompt the user again)
            Logger.info("SynologyUserLogin#performPasswordLogin, OTP input required, code=\(code), message: \(msg)")
            continuation.yield(.otpRequired)
            continuation.finish()
        } catch let SynologyError.auth(code, message) where
            (renewingExpiredSession && (400...411).contains(code)) || SynologyErrorCode(rawValue: code).toSynologyError().isServerSessionExpired {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            // 服务器明确会话失效，或已知失效会话的续期凭据被拒绝，都需要用户重新登录；网络包装的 code -1 不进入此分支。
            Logger.warn("SynologyUserLogin#performPasswordLogin, renewal credentials rejected, code=\(code)")
            continuation.yield(.invalidSession(message: message))
            continuation.finish()
        } catch let error as SynologyError where error.isServerSessionExpired {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
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

    /// 区分服务器明确失效与校验不可用，避免恢复流程误清仍然有效的 SID。
    enum SliceLoginOutcome {
        case completed
        case skipped
        case invalidSession
        case cancelled
        case failed(Error)
    }

    /// 在当前解析出的地址上校验原 SID。只有 106/107/119 可触发全量登录，其他错误交给调用方结束恢复。
    func attemptSliceValidation(connection: SynologyConnection,
                                serverType: ServerType,
                                continuation: AsyncStream<SynologyUserLoginProgress>.Continuation) async -> SliceLoginOutcome {
        guard let sessionInfo = apiClient.session ?? keyChainStorage.getSessionInfo(), !sessionInfo.sid.isEmpty else {
            return .skipped
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
            try sessionOperations.commitState {
                saveConnection(url: connection.url, type: connection.type)
            }

            Logger.info("SynologyUserLogin#attemptSliceValidation, hit, sid=\(Logger.maskedSessionValue(sessionInfo.sid))")
            continuation.yield(.completed(result: loginResult))
            continuation.finish()
            return .completed
        } catch let error as SynologyError where error.isServerSessionExpired {
            return .invalidSession
        } catch is CancellationError {
            return .cancelled
        } catch let error as URLError where error.code == .cancelled {
            return .cancelled
        } catch {
            return .failed(error)
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

    func commitCredentials(
        server: String,
        usesHTTPS: Bool,
        username: String,
        password: String,
        shouldSavePassword: Bool
    ) {
        if shouldSavePassword {
            keyChainStorage.saveCredentials(
                server: server,
                username: username,
                password: password,
                usesHTTPS: usesHTTPS
            )
        } else {
            keyChainStorage.removeCredentials()
        }
    }

    func rollbackConnection(to connection: SynologyConnection?) {
        guard let connection else {
            return
        }

        sessionOperations.rollback {
            apiClient.updateConnection(type: connection.type, url: connection.url)
        }
    }

    func rollbackSession(to session: (sid: String, did: String?)?) {
        sessionOperations.rollback {
            guard let session else { apiClient.clearSession(); return }
            apiClient.updateSession(sid: session.sid, did: session.did)
        }
    }
}
