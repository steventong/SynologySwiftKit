//
//  File.swift
//
//
//  Created by Steven on 2024/5/2.
//

import Foundation

public class DeviceConnection {
    public init() {
    }

    /**
     当前URL
     */
    public func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)? {
        if let url = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName) {
            let type = UserDefaults.standard.integer(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            if let typeEnum = ConnectionType(rawValue: type) {
                Logger.info("getCurrentConnectionUrl, type = \(typeEnum), url = \(url)")
                return (typeEnum, url)
            }
        }

        Logger.info("getCurrentConnectionUrl, url = nil")
        return nil
    }
}

extension DeviceConnection {
    /**
     saveCurrentConnectionUrl
     */
    func saveCurrentConnectionUrl(type: ConnectionType?, url: String?) {
        DispatchQueue.main.async {
            if let type, let url {
                UserDefaults.standard.setValue(type.rawValue, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
                UserDefaults.standard.setValue(url, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)

                Logger.info("saveCurrentConnectionUrl, save type = \(type), url = \(url)")
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)

                Logger.info("saveCurrentConnectionUrl, removeObject type, url")
            }

            UserDefaults.standard.synchronize()
        }
    }

    /**
     removeCurrentConnectionUrl
     */
    func removeCurrentConnectionUrl() {
        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)

            UserDefaults.standard.synchronize()
            Logger.info("saveCurrentConnectionUrl, removeObject type, url")
        }
    }
}
