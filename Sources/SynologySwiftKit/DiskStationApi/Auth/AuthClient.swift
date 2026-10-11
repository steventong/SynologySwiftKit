//
//  AuthClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - AuthClient

protocol AuthenticationProviding {
    func login(username: String, password: String, otpCode: String?) async throws -> AuthResult
}

/// Synology 登录/登出客户端
/// Synology login/logout client
///
/// 封装 `SYNO.API.Auth` 登录接口，支持密码登录和 OTP 双验证。
/// Wraps the `SYNO.API.Auth` login endpoint; supports password login and OTP two-factor authentication.
public final class AuthClient {
    private let sessionOperations: SessionOperationCoordinator
    private let apiClient: ApiRequestSending & SessionStateUpdating
    private let keyChainStorage: any SensitiveStorage

    /// 初始化登录客户端
    /// Initialize login client
    init(apiClient: ApiRequestSending & SessionStateUpdating, keyChainStorage: any SensitiveStorage = StorageService(), sessionOperations: SessionOperationCoordinator = SessionOperationCoordinator()) {
        self.sessionOperations = sessionOperations
        self.apiClient = apiClient
        self.keyChainStorage = keyChainStorage
    }

    /// 使用账号密码登录
    /// Login with username and password
    /// - Parameters:
    ///   - username: 用户名 / Username
    ///   - password: 密码 / Password
    ///   - otpCode: OTP 验证码（启用了双验证时传入）/ OTP code (provide when 2FA is enabled)
    /// - Returns: 登录结果（含 SID/DID）/ Login result (with SID/DID)
    /// - Throws:
    ///   - `SynologyError.auth`: 登录失败 / Login failed
    ///   - `SynologyError.authError`: API 错误码映射 / API error code mapping
    public func login(username: String, password: String, otpCode: String? = nil) async throws -> AuthResult {
        try await sessionOperations.perform { [self] in
            try await authenticate(username: username, password: password, otpCode: otpCode)
        }
    }

    private func authenticate(username: String, password: String, otpCode: String?) async throws -> AuthResult {
        let deviceInfo = keyChainStorage.getDeviceInfo()
        let normalizedOTPCode = otpCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let deviceName = deviceInfo?.1 ?? "SynologySwiftKit"

        do {
            let api = ApiEndpoint(api: SynologyApi.Core.AUTH, method: "login", version: 6, httpMethod: .post, timeout: 10) {
                ("account", username)
                ("passwd", password)
                ("format", "cookie")
                ("session", "SynologySwiftKit")
                ("client_time", String(Int(Date().timeIntervalSince1970)))
                if let normalizedOTPCode {
                    ("otp_code", normalizedOTPCode)
                    ("enable_device_token", "yes")
                }
                if let deviceInfo, !deviceInfo.0.isEmpty {
                    ("device_id", deviceInfo.0)
                    ("device_name", deviceInfo.1)
                }
            }
            let authResult: AuthResult = try await apiClient.request(api)

            // save device id and name
            if let did = authResult.did, !did.isEmpty {
                try sessionOperations.commit { keyChainStorage.saveDeviceInfo(did, deviceName) }
            }

            return handleAuthResult(authResult: authResult)
        } catch is CancellationError {
            throw CancellationError()
        } catch let SynologyError.sessionExpired(code, msg) {
            throw SynologyError.auth(code: code, message: msg)
        } catch let SynologyError.api(code, _) {
            throw SynologyError.authError(code: code)
        } catch let error as SynologyError {
            throw error
        } catch {
            throw SynologyError.auth(code: -1, message: "login failed: \(error.localizedDescription)")
        }
    }

    /// 登出并清除内存和 Keychain 中的会话信息
    /// Logout and clear session info from memory and Keychain
    public func logout() async throws {
        try await sessionOperations.perform { [self] in
            let api = ApiEndpoint(api: SynologyApi.Core.AUTH, method: "logout", version: 6, timeout: 3)
            let _: EmptyData = try await apiClient.request(api)
            try sessionOperations.commitState {
                apiClient.clearSession()
                keyChainStorage.removeSessionInfo()
            }
        }
    }

    /// Queries SYNO.API.Auth.token (v6), documented in the DSM Login Web API Guide.
    /// Returns the API envelope without changing the session or storing the returned SynoToken.
    /// An explicit SID is sent without ambient cookies. This is not a guaranteed SID validation API.
    public func token(sid: String? = nil) async throws -> DSMReadResponse {
        try await apiClient.requestEnvelope(ApiEndpoint(
            api: SynologyApi.Core.AUTH, method: "token", version: 6,
            httpMethod: .get, sidOnQuery: sid == nil, sidOnCookie: false
        ) {
            if let sid { ("_sid", sid) }
        })
    }

    /// 读取已保存的登录凭据
    /// Read saved login credentials
    public func getCredentials() -> SynologyCredentials? {
        keyChainStorage.getCredentials()
    }

    /// 读取成功登录过的账号历史。
    /// Read successfully authenticated account history.
    public func getLoginAccountHistory() -> [SynologyLoginAccountHistoryItem] {
        keyChainStorage.getLoginAccountHistory()
    }

    /// 删除指定历史登录账号。
    /// Remove a login account history item.
    public func removeLoginAccountFromHistory(id: UUID) {
        keyChainStorage.removeLoginAccountFromHistory(id: id)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension AuthClient: AuthenticationProviding {}

extension AuthClient {
    /// 处理登录结果（当前仅记录日志）
    /// Handle login result (currently only logs the result)
    private func handleAuthResult(authResult: AuthResult) -> AuthResult {
        Logger.info(
            "AuthClient#handleAuthResult success, \(Logger.sessionSummary(sid: authResult.sid, did: authResult.did)), hasSynoToken=\(authResult.synotoken?.isEmpty == false)"
        )
        return authResult
    }
}
