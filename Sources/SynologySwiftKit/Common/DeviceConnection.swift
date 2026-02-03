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

    /// 注入的存储依赖
    private let storage: KeyValueStorage

    private let ONE_WEEK_SECONDS = 604800
    private let ONE_YEAR_SECONDS = 31536000

    /// 初始化设备连接管理器
    /// Initialize device connection manager
    /// - Parameter storage: 键值存储实现（默认 UserDefaults）
    public init(storage: KeyValueStorage = UserDefaultsStorage()) {
        self.storage = storage
    }

    /// 获取当前URL
    public func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)? {
        if let connection {
            return connection
        }

        if let connectionUrl = storage.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName),
           let typeRawValue = storage.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName),
           let connectionType = ConnectionType(rawValue: typeRawValue) {
            let current = (connectionType, connectionUrl)
            connection = current
            Logger.info("[DeviceConnection]get connection-url from storage, connection url = \(current)")
            return current
        }

        Logger.warn("[DeviceConnection] Invalid or missing connection configuration. Logging out.")
        removeLoginSession()

        return nil
    }

    /// 获取当前用户名
    public func getSessionUsername() -> String? {
        return storage.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_USERNAME.keyName)
    }

    /// 获取登录session
    public func getLoginSession() -> (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)? {
        if let session {
            return session
        }

        let sid = storage.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        let sidExpireAt = storage.object(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName) as? Date

        let did = storage.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
        let didExpireAt = storage.object(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName) as? Date

        if let sid, let sidExpireAt {
            let current = (sid, sidExpireAt, did, didExpireAt)
            session = current
            return current
        }

        Logger.warn("[DeviceConnection]getLoginSession, session from storage is invalid")
        return nil
    }

    /// 获取登录服务器信息
    public func getLoginServer() -> (server: String, isEnableHttps: Bool)? {
        if let loginServer {
            return loginServer
        }

        if let server = storage.string(forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName) {
            let isEnableHttps = storage.bool(forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)
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

        storage.set(sid, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        storage.set(currentSession.sidExpireAt, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName)

        if let did {
            storage.set(did, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            storage.set(currentSession.didExpireAt, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)
        } else {
            storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)
        }

        storage.set(username, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_USERNAME.keyName)
        Logger.info("[DeviceConnection]updateLoginSession saved to storage")
    }

    /**
     保存当前的URL
     */
    public func updateCurrentConnectionUrl(type: ConnectionType, url: String) {
        connection = (type, url)

        storage.set(url, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        storage.set(type.rawValue, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)

        Logger.info("[DeviceConnection]update Connection to storage, url = \(url)")
    }

    /**
     removeLoginSession
     */
    public func removeLoginSession() {
        session = nil
        loginServer = nil
        connection = nil

        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName)
        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)

        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_USERNAME.keyName)

        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName)
        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)

        Logger.info("[DeviceConnection]removeLoginSession from storage")
    }

    /**
     登录偏好
     */
    public func updateLoginPreferences(server: String, isEnableHttps: Bool) {
        loginServer = (server, isEnableHttps)

        storage.set(server, forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName)
        storage.set(isEnableHttps, forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)

        Logger.info("[DeviceConnection]updateLoginPreferences to storage")
    }

    /**
     removeCurrentConnectionUrl
     */
    public func removeCurrentConnectionUrl() {
        connection = nil
        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
        storage.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        Logger.info("[DeviceConnection]removeCurrentConnectionUrl from storage")
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
