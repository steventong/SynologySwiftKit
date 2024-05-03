//
//  File.swift
//
//
//  Created by Steven on 2024/5/2.
//

import Foundation

public class DeviceConnection {
    public static let shared = DeviceConnection()

    private var connection: (type: ConnectionType, url: String)?
    private var session: (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)?

    private let ONE_WEEK_SECONDS = 604800
    private let ONE_YEAR_SECONDS = 31536000
    /**
     获取当前URL
     */
    public func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)? {
        if let connection {
            return connection
        }

        if let url = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName) {
            let type = UserDefaults.standard.integer(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            if let typeEnum = ConnectionType(rawValue: type) {
                Logger.info("getCurrentConnectionUrl, typeEnum = \(typeEnum), url = \(url)")
                connection = (typeEnum, url)
                return connection
            }
        }

        Logger.info("getCurrentConnectionUrl, url = nil")
        return nil
    }

    /**
     保存当前的URL
     */
    public func updateCurrentConnectionUrl(type: ConnectionType, url: String) {
        connection = (type, url)

        DispatchQueue.main.async {
            UserDefaults.standard.setValue(type.rawValue, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            UserDefaults.standard.setValue(url, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)

            UserDefaults.standard.synchronize()
            Logger.info("saveCurrentConnectionUrl, save type = \(type), url = \(url)")
        }
    }

    /**
     sid, did
     */
    public func getLoginSession() -> (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)? {
        if let session {
            return session
        }

        let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        let sidExpireAt: Date? = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName) as? Date ?? nil
        let did = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
        let didExpireAt: Date? = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName) as? Date ?? nil

        if let sid, let sidExpireAt {
            let session = (sid, sidExpireAt, did, didExpireAt)
            Logger.info("getLoginSession, session = \(session)")
            return session
        }

        return nil
    }

    /**
     update sid
     */
    public func updateLoginSession(sid: String, did: String?) {
        let sidExpireAt = addSecondsFromNow(seconds: ONE_WEEK_SECONDS)
        if let did {
            let didExpireAt = addSecondsFromNow(seconds: ONE_YEAR_SECONDS)
            session = (sid, sidExpireAt, did, didExpireAt)
        } else {
            session = (sid, sidExpireAt, nil, nil)
        }

        guard let session else {
            return
        }

        DispatchQueue.main.async {
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
            Logger.info("updateLoginSession")
        }
    }

    /**
     removeLoginSession
     */
    public func removeLoginSession() {
        session = nil

        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT.keyName)

            UserDefaults.standard.synchronize()
            Logger.info("removeLoginSession")
        }
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
            Logger.info("removeCurrentConnectionUrl, removeObject type, url")
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
