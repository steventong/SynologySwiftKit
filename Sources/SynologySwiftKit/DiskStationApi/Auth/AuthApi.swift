//
//  AuthApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public actor AuthApi {
    private let apiClient: ApiClientProviding
    private let storage: KeyValueStorage

    public init(apiClient: ApiClientProviding, storage: KeyValueStorage = UserDefaultsStorage()) {
        self.apiClient = apiClient
        self.storage = storage
    }

    public func userLogin(server: String, username: String, password: String, otpCode: String? = nil) async throws -> AuthResult {
        Logger.debug("send request: userLogin, \(server), \(username)")

        let deviceName = getDeviceName()
        let deviceId = getDeviceId()

        do {
            let authResult: AuthResult = try await apiClient.request(
                ApiEndpoint(
                    api: SynologyApi.Core.AUTH, method: "login", version: 6, httpMethod: .post,
                    parameters: [
                        "account": username,
                        "passwd": password,
                        "format": "cookie",
                        "otp_code": otpCode ?? "",
                        "enable_syno_token": "no",
                        "enable_device_token": otpCode != nil ? "yes" : "no",
                        "device_name": deviceName,
                        "device_id": deviceId ?? "",
                        "session": "AudioStation",
                    ], timeout: 10),
                resultType: AuthResult.self
            )
            return handleAuthResult(authResult: authResult)
        } catch let SynologyError.api(.invalidSession(code, msg)) {
            throw SynologyError.auth(.undefined(code: code, message: msg))
        } catch let SynologyError.api(.businessError(code, msg)) {
            throw SynologyError.auth(SynologyError.AuthError.fromCode(code, message: msg))
        } catch let error as SynologyError {
            throw error
        } catch {
            throw SynologyError.auth(
                .undefined(code: -1, message: "login failed: \(error.localizedDescription)"))
        }
    }

    public func logout() async throws {
        try await apiClient.request(
            ApiEndpoint(api: SynologyApi.Core.AUTH, method: "logout", version: 6, timeout: 3)
        )
    }
}

extension AuthApi {
    public func getDeviceName() -> String {
        let deviceNameKey = UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_NAME.keyName
        if let deviceName = storage.string(forKey: deviceNameKey) {
            return deviceName
        }
        let deviceName = UUID().uuidString
        storage.set(deviceName, forKey: deviceNameKey)
        return deviceName
    }

    private func getDeviceId() -> String? {
        storage.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_ID.keyName)
    }

    private func setDeviceId(deviceId: String) {
        storage.set(deviceId, forKey: UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_ID.keyName)
    }

    private func handleAuthResult(authResult: AuthResult) -> AuthResult {
        if let did = authResult.did {
            setDeviceId(deviceId: did)
        }
        Logger.info("authResult: \(authResult)")
        return authResult
    }
}
