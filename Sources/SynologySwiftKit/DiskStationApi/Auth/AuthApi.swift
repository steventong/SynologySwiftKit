//
//  AuthApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public actor AuthApi {
    private let apiClient: ApiClientProviding
    private let deviceConnection: DeviceConnectionProviding

    public init(apiClient: ApiClientProviding, deviceConnection: DeviceConnectionProviding) {
        self.apiClient = apiClient
        self.deviceConnection = deviceConnection
    }

    public func userLogin(server: String, username: String, password: String, otpCode: String? = nil) async throws -> AuthResult {
        Logger.debug("send request: userLogin, \(server), \(username)")

        let deviceName = await deviceConnection.getDeviceName()
        let deviceId = await deviceConnection.getPersistentDeviceId()

        do {
            let api = ApiEndpoint(api: SynologyApi.Core.AUTH, method: "login", version: 6, httpMethod: .post,
                                  parameters: ["account": username,
                                               "passwd": password,
                                               "format": "cookie",
                                               "otp_code": otpCode ?? "",
                                               "enable_syno_token": "no",
                                               "enable_device_token": otpCode != nil ? "yes" : "no",
                                               "device_name": deviceName,
                                               "device_id": deviceId ?? "",
                                               "session": "AudioStation"],
                                  timeout: 10)
            let authResult: AuthResult = try await apiClient.request(api, resultType: AuthResult.self)
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
        // DeviceConnection will handle saving the new DID if present
        Logger.info("authResult: \(authResult)")
        return authResult
    }
}
