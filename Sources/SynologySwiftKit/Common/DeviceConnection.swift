//
//  File.swift
//
//
//  Created by Steven on 2024/5/2.
//

import Foundation

public class DeviceConnection {
    public static let shared = DeviceConnection()

    private var loginPreference: (server: String, isEnableHttps: Bool)?
    private var connection: (type: ConnectionType, url: String)?
    private var session: (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)?

    private let ONE_WEEK_SECONDS = 604800
    private let ONE_YEAR_SECONDS = 31536000
    /**
     获取当前URL
     */
    public func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)? {
        if let connection {
//            Logger.info("[DeviceConnection]query Connection from context, connection = \(connection)")
            return connection
        }

        if let url = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName) {
            let typeRawValuw = UserDefaults.standard.integer(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            if let type = ConnectionType(rawValue: typeRawValuw) {
                connection = (type, url)
//                Logger.warn("[DeviceConnection]query Connection from userdefaults, connection = \(connection)")
                return connection
            }
        }

        Logger.error("[DeviceConnection]query Connection fail, connection is nil")
        return nil
    }

    /**
     保存当前的URL
     */
    public func updateCurrentConnectionUrl(type: ConnectionType, url: String) {
        connection = (type, url)
//        Logger.info("[DeviceConnection]prepare update Connection to userdefaults, connection = \(connection)")

        UserDefaults.standard.setValue(url, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        UserDefaults.standard.setValue(type.rawValue, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)

        UserDefaults.standard.synchronize()
//        Logger.info("[DeviceConnection]update Connection to userdefaults, connection = \(connection)")
    }

    /**
     sid, did
     */
    public func getLoginSession() -> (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)? {
        if let session {
//            Logger.info("[DeviceConnection]getLoginSession, session is valid")
            return session
        }

        let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        let sidExpireAt: Date? = UserDefaults.standard.object(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName) as? Date ?? nil
        let did = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
        let didExpireAt: Date? = UserDefaults.standard.object(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName) as? Date ?? nil

        if let sid, let sidExpireAt {
            let session = (sid, sidExpireAt, did, didExpireAt)
//            Logger.info("[DeviceConnection]getLoginSession, session = \(session)")
            return session
        }

        Logger.info("[DeviceConnection]getLoginSession, session from userdefaults is invalid")
        return nil
    }

    /**
     update sid
     */
    public func updateLoginSession(sid: String, did: String?) {
        let sidExpireAt = addSecondsFromNow(seconds: ONE_WEEK_SECONDS)
//        Logger.debug("update login session, sid will expire at: \(sidExpireAt)")

        if let did {
            let didExpireAt = addSecondsFromNow(seconds: ONE_YEAR_SECONDS)
            session = (sid, sidExpireAt, did, didExpireAt)
//            Logger.debug("update login session, did is present, session: \(session)")
        } else {
            session = (sid, sidExpireAt, nil, nil)
//            Logger.debug("update login session, session: \(session)")
        }

        guard let session else {
            return
        }

        UserDefaults.standard.setValue(sid, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        UserDefaults.standard.setValue(session.sidExpireAt, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName)

        if let did {
            UserDefaults.standard.setValue(did, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            UserDefaults.standard.setValue(session.didExpireAt, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)
        } else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)
        }

        UserDefaults.standard.synchronize()
        Logger.info("[DeviceConnection]updateLoginSession userdefaults synchronize")
    }

    /**
     removeLoginSession
     */
    public func removeLoginSession() {
        session = nil

        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)

            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)

            UserDefaults.standard.synchronize()
            Logger.info("[DeviceConnection]removeLoginSession userdefaults synchronize")
        }
    }

    /**
     登录偏好
     */
    public func updateLoginPreferences(server: String, isEnableHttps: Bool) {
        loginPreference = (server, isEnableHttps)

        UserDefaults.standard.setValue(server, forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName)
        UserDefaults.standard.setValue(isEnableHttps, forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)

        UserDefaults.standard.synchronize()
        Logger.info("[DeviceConnection]updateLoginPreferences userdefaults synchronize")
    }

    /**
     登录偏好
     */
    public func getLoginPreferences() -> (server: String, isEnableHttps: Bool)? {
        if let loginPreference {
            return loginPreference
        }

        if let server = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_SERVER.keyName) {
            let isEnableHttps = UserDefaults.standard.bool(forKey: UserDefaultsKeys.DISK_STATION_SERVER_ENABLE_HTTPS.keyName)

            loginPreference = (server, isEnableHttps)

            return loginPreference
        }

        return nil
    }
}

extension DeviceConnection {
    /**
     removeCurrentConnectionUrl
     */
    func removeCurrentConnectionUrl() {
        connection = nil

        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)

            UserDefaults.standard.synchronize()
            Logger.info("[DeviceConnection]removeCurrentConnectionUrl, removeObject type, url")
        }
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
