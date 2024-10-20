//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

public actor AuthApi {
    public init() {
    }

    /**
     Logs into the DSM (DiskStation Manager) with the provided credentials.

     - Parameters:
        - account: Login account name.
        - passwd: Login account password.
        - session: (Optional) Login session name for DSM Applications.
        - format: (Optional) Returned format of session ID.
          Following are the two possible options and the default value is `cookie`.
            - cookie: The login session ID will be set to "id" key in the cookie of HTTP/HTTPS header of the response.
            - sid: The login sid will only be returned as response JSON data and "id" key will not be set in the cookie.
        - otp_code: (Optional) 2-factor authentication option with an OTP code. If enabled, the user requires a verification code to log into DSM sessions.
        - enable_syno_token: (Optional) Obtain the CSRF token, also known as SynoToken, for the subsequent request. If set to false, the server will not produce this token.
        - enable_device_token: (Optional) Omit 2-factor authentication (OTP) with a device id for the next login request.
        - device_name: (Optional) To identify which device can be omitted from 2-factor authentication (OTP), pass this value will skip it.
        - device_id: (Optional) If 2-factor authentication (OTP) has omitted the same enabled device id, pass this value to skip it.
     */
    public func userLogin(server: String, username: String, password: String, otpCode: String? = nil) async throws -> AuthResult {
        Logger.debug("send request: userLogin, \(server), \(username)")

        let deviceName = getDeviceName()
        let deviceId = getDeviceId()

        let api = try DiskStationApi(api: .SYNO_API_AUTH, method: "login", version: 6, httpMethod: .post, parameters: [
            "account": username,
            "passwd": password,
            "format": "cookie",
            "otp_code": otpCode ?? "",
            "enable_syno_token": "no",
            "enable_device_token": otpCode != nil ? "yes" : "no",
            "device_name": deviceName,
            "device_id": deviceId ?? "",
            "session": "AudioStation",
        ], timeout: 10)

        do {
            let authResult = try await api.requestForData(resultType: AuthResult.self)
            return handleAuthResult(authResult: authResult)
        } catch let DiskStationApiError.invalidSession(errorCode, errorMsg) {
            // invalid session
            throw AuthApiError.invalidSession(errorCode, errorMsg)
        } catch let DiskStationApiError.apiBizError(errorCode, errorMsg) {
            // 处理登录失败的错误码
            throw AuthApiError.getAuthApiErrorByCode(errorCode: errorCode, errorMsg: errorMsg)
        } catch let commonError as DiskStationApiError {
            // 其他错误
            throw AuthApiError.undefindedError(commonError.localizedDescription)
        } catch {
            // 其他错误
            throw AuthApiError.undefindedError("login failed, unknown error: \(error)")
        }
    }

    /**
     logout
     */
    public func logout() async throws {
        let api = try DiskStationApi(api: .SYNO_API_AUTH, method: "logout", version: 6, timeout: 3)
        try await api.request()
    }
}

extension AuthApi {
    /**
     getDeviceName
     */
    public func getDeviceName() -> String {
        let deviceNameKey = UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_NAME.keyName
        if let deviceName = UserDefaults.standard.string(forKey: deviceNameKey) {
            return deviceName
        }

        let deviceName = UUID().uuidString
        UserDefaults.standard.setValue(deviceName, forKey: deviceNameKey)

        return deviceName
    }

    /**
     getDeviceId
     */
    private func getDeviceId() -> String? {
        let deviceIdKey = UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_ID.keyName
        return UserDefaults.standard.string(forKey: deviceIdKey)
    }

    /**
     setDeviceId
     */
    private func setDeviceId(deviceId: String) {
        let deviceIdKey = UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_ID.keyName
        UserDefaults.standard.setValue(deviceId, forKey: deviceIdKey)
    }

    /**
     handleAuthResult
     */
    private func handleAuthResult(authResult: AuthResult) -> AuthResult {
        // If 2-factor authentication (OTP) has omitted the same enabled device id, pass this value to skip it.
        if let did = authResult.did {
            setDeviceId(deviceId: did)
        }

        Logger.info("authResult: \(authResult)")
        return authResult
    }
}
