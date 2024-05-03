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
}
