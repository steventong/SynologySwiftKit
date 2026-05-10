//
//  AuthClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - AuthClient

/// Synology 登录/登出客户端
/// Synology login/logout client
///
/// 封装 `SYNO.API.Auth` 登录接口，支持密码登录和 OTP 双验证。
/// Wraps the `SYNO.API.Auth` login endpoint; supports password login and OTP two-factor authentication.
public final class AuthClient {
    private let apiClient: ApiRequestSending & SessionStateUpdating
    private let keyChainStorage: any SensitiveStorage

    /// 初始化登录客户端
    /// Initialize login client
    init(apiClient: ApiRequestSending & SessionStateUpdating, keyChainStorage: any SensitiveStorage = StorageService()) {
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
        let deviceIdAndName = keyChainStorage.getDeviceInfo() ?? ("", UUID().uuidString)

        do {
            let api = ApiEndpoint(api: SynologyApi.Core.AUTH, method: "login", version: 6, httpMethod: .post, timeout: 10) {
                ("account", username)
                ("passwd", password)
                ("format", "cookie")
                ("otp_code", otpCode ?? "")
                ("enable_syno_token", "no")
                ("enable_device_token", otpCode != nil ? "yes" : "no")
                ("device_id", deviceIdAndName.0)
                ("device_name", deviceIdAndName.1)
                ("session", "AudioStation")
            }
            let authResult: AuthResult = try await apiClient.request(api)

            // save device id and name
            if let did = authResult.did, !did.isEmpty {
                keyChainStorage.saveDeviceInfo(did, deviceIdAndName.1)
            }

            return handleAuthResult(authResult: authResult)
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
        let api = ApiEndpoint(api: SynologyApi.Core.AUTH, method: "logout", version: 6, timeout: 3)
        let _: EmptyData = try await apiClient.request(api)
        apiClient.clearSession()
        keyChainStorage.removeSessionInfo()
    }

    /// 读取已保存的登录凭据
    /// Read saved login credentials
    public func getCredentials() -> SynologyCredentials? {
        keyChainStorage.getCredentials()
    }
}

extension AuthClient {
    /// 处理登录结果（当前仅记录日志）
    /// Handle login result (currently only logs the result)
    private func handleAuthResult(authResult: AuthResult) -> AuthResult {
        Logger.info("authResult: \(authResult)")
        return authResult
    }
}
