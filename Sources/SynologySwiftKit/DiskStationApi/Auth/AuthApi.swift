//
//  AuthApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public actor AuthApi {
    private let apiClient: ApiClientProviding
    private let keychainStorage: KeychainStorage

    public init(apiClient: ApiClientProviding, keychainStorage: KeychainStorage = KeychainStorage()) {
        self.apiClient = apiClient
        self.keychainStorage = keychainStorage
    }

    public func userLogin(server: String, username: String, password: String, otpCode: String? = nil) async throws -> AuthResult {
        Logger.debug("send request: userLogin, \(server), \(username)")

        let deviceName = keychainStorage.getDeviceName() ?? UUID().uuidString
        let deviceId = keychainStorage.getDeviceId() ?? ""

        do {
            let api = ApiEndpoint(api: SynologyApi.Core.AUTH,
                                  method: "login",
                                  version: 6,
                                  httpMethod: .post,
                                  parameters: ["account": username,
                                               "passwd": password,
                                               "format": "cookie",
                                               "otp_code": otpCode ?? "",
                                               "enable_syno_token": "no",
                                               "enable_device_token": otpCode != nil ? "yes" : "no",
                                               "device_name": deviceName,
                                               "device_id": deviceId,
                                               "session": "AudioStation"],
                                  timeout: 10)
            let authResult: AuthResult = try await apiClient.request(api, resultType: AuthResult.self)

            // Persist device identity for future use
            keychainStorage.saveDeviceName(deviceName)
            if let did = authResult.did, !did.isEmpty {
                keychainStorage.saveDeviceId(did)
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
        try await apiClient.request(
            ApiEndpoint(api: SynologyApi.Core.AUTH, method: "logout", version: 6, timeout: 3)
        )
    }
}

extension AuthApi {
    private func handleAuthResult(authResult: AuthResult) -> AuthResult {
        Logger.info("authResult: \(authResult)")
        return authResult
    }
}
