//
//  DeviceConnection.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/5/2.
//

import Foundation

/// 设备连接管理器 (Actor 保证并发安全)
public actor DeviceConnection: DeviceConnectionProviding {
    private var loginServer: (server: String, isEnableHttps: Bool)?
    private var connection: (type: ConnectionType, url: String)?
    private var session: (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)?

    private let ONE_WEEK_SECONDS = 604800
    private let ONE_YEAR_SECONDS = 31536000

    /// 初始化设备连接管理器
    /// Initialize device connection manager
    public init() {}
    
    /**
     获取当前URL
     */
    public func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)? {
        if let connection {
            return connection
        }

        if let url = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName) {
            let typeRawValue = UserDefaults.standard.integer(
                forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            if let type = ConnectionType(rawValue: typeRawValue) {
                let current = (type, url)
                connection = current
                Logger.info(
                    "[DeviceConnection]get connection-url from userdefaults, connection url = \(current)"
                )
                return current
            }
        }

        Logger.info("[DeviceConnection]can not get saved connection-url info in userdefaults.")
        return nil
    }

    /**
     用户名
     */
    public func getSessionUsername() -> String? {
        return UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_USERNAME.keyName)
    }

    /**
     sid, did
     */
    public func getLoginSession() -> (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)? {
        if let session {
            return session
        }

        let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        let sidExpireAt: Date? = UserDefaults.standard.object(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName) as? Date

        let did = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
        let didExpireAt: Date? = UserDefaults.standard.object(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName) as? Date

        if let sid, let sidExpireAt {
            let current = (sid, sidExpireAt, did, didExpireAt)
            session = current
            return current
        }

        Logger.warn("[DeviceConnection]getLoginSession, session from userdefaults is invalid")
        return nil
    }

    /**
     登录偏好
     */
    public func getLoginServer() -> (server: String, isEnableHttps: Bool)? {
        if let loginServer {
            return loginServer
        }

        if let server = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName) {
            let isEnableHttps = UserDefaults.standard.bool(forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)
            let current = (server, isEnableHttps)
            loginServer = current
            return current
        }

        return nil
    }

    /**
     update sid/did
     */
    public func updateLoginSession(username: String, sid: String, did: String?) {
        let sidExpireAt = addSecondsFromNow(seconds: ONE_WEEK_SECONDS)
        Logger.debug("update login session, sid will expire at: \(sidExpireAt)")

        if let did {
            let didExpireAt = addSecondsFromNow(seconds: ONE_YEAR_SECONDS)
            session = (sid, sidExpireAt, did, didExpireAt)
        } else {
            session = (sid, sidExpireAt, nil, nil)
        }

        guard let currentSession = session else {
            return
        }
        Logger.debug("update login session, session: \(currentSession)")

        UserDefaults.standard.setValue(sid, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        UserDefaults.standard.setValue(currentSession.sidExpireAt, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName)

        if let did {
            UserDefaults.standard.setValue(did, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            UserDefaults.standard.setValue(currentSession.didExpireAt, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)
        } else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)
        }

        UserDefaults.standard.setValue(username, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_USERNAME.keyName)
        Logger.info("[DeviceConnection]updateLoginSession saved to userdefaults")
    }

    /**
     保存当前的URL
     */
    public func updateCurrentConnectionUrl(type: ConnectionType, url: String) {
        connection = (type, url)

        UserDefaults.standard.setValue(url, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        UserDefaults.standard.setValue(type.rawValue, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)

        Logger.info("[DeviceConnection]update Connection to userdefaults, url = \(url)")
    }

    /**
     removeLoginSession
     */
    public func removeLoginSession() {
        session = nil
        loginServer = nil
        connection = nil

        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)

        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_USERNAME.keyName)

        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)

        Logger.info("[DeviceConnection]removeLoginSession from userdefaults")
    }

    /**
     登录偏好
     */
    public func updateLoginPreferences(server: String, isEnableHttps: Bool) {
        loginServer = (server, isEnableHttps)

        UserDefaults.standard.setValue(server, forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName)
        UserDefaults.standard.setValue(isEnableHttps, forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)

        Logger.info("[DeviceConnection]updateLoginPreferences to userdefaults")
    }

    /**
     removeCurrentConnectionUrl
     */
    public func removeCurrentConnectionUrl() {
        connection = nil
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        Logger.info("[DeviceConnection]removeCurrentConnectionUrl from userdefaults")
    }

    /**
     addSecondsFromNow
     */
    private func addSecondsFromNow(seconds: Int) -> Date {
        if let newDate = Calendar.current.date(byAdding: .second, value: seconds, to: Date()) {
            return newDate
        }
        return Date()
    }
}
