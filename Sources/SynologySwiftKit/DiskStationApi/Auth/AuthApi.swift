//
//  AuthApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public class AuthApi {
    private let apiClient: ApiClientProviding
    private let keyChainStorage: KeyChainStorage

    public init(apiClient: ApiClientProviding, keyChainStorage: KeyChainStorage = KeyChainStorage()) {
        self.apiClient = apiClient
        self.keyChainStorage = keyChainStorage
    }

    public func login(username: String, password: String, otpCode: String? = nil) async throws -> AuthResult {
        let deviceIdAndName = keyChainStorage.getDeviceInfo() ?? ("", UUID().uuidString)

        do {
            let api = ApiEndpoint(api: SynologyApi.Core.AUTH, method: "login", version: 6, httpMethod: .post,
                                  parameters: ["account": username,
                                               "passwd": password,
                                               "format": "cookie",
                                               "otp_code": otpCode ?? "",
                                               "enable_syno_token": "no",
                                               "enable_device_token": otpCode != nil ? "yes" : "no",
                                               "device_id": deviceIdAndName.0,
                                               "device_name": deviceIdAndName.1,
                                               "session": "AudioStation"],
                                  timeout: 10)
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

    public func logout() async throws {
        let api = ApiEndpoint(api: SynologyApi.Core.AUTH, method: "logout", version: 6, timeout: 3)
        let _: EmptyData = try await apiClient.request(api, rawResponse: false)
    }

    /// 读取已保存的登录凭据
    /// Read saved login credentials
    public func getCredentials() -> (server: String, username: String, password: String, isEnableHttps: Bool)? {
        keyChainStorage.getCredentials()
    }
}

extension AuthApi {
    private func handleAuthResult(authResult: AuthResult) -> AuthResult {
        Logger.info("authResult: \(authResult)")
        return authResult
    }
}
