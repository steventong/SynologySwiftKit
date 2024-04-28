//
//  File.swift
//
//
//  Created by Steven on 2024/4/28.
//

import Foundation

enum UserDefaultsKeys {
    case SYNOLOGY_SERVER_URL(String)
    case DISK_STATION_CONNECTION_URL
    case DISK_STATION_CONNECTION_TYPE
    case DISK_STATION_AUTH_DEVICE_NAME
    case DISK_STATION_AUTH_DEVICE_ID
    case DISK_STATION_AUTH_SESSION_ID

    var keyName: String {
        switch self {
        case let .SYNOLOGY_SERVER_URL(quickConnectId):
            return "SynologySwiftKit_SynologyServer_\(quickConnectId)"
        case .DISK_STATION_CONNECTION_URL:
            return "SynologySwiftKit_DiskStation_ConnectionURL"
        case .DISK_STATION_CONNECTION_TYPE:
            return "SynologySwiftKit_DiskStation_ConnectionType"
        case .DISK_STATION_AUTH_DEVICE_NAME:
            return "SynologySwiftKit_DiskStation_Auth_DeviceName"
        case .DISK_STATION_AUTH_DEVICE_ID:
            return "SynologySwiftKit_DiskStation_Auth_DeviceID"
        case .DISK_STATION_AUTH_SESSION_ID:
            return "SynologySwiftKit_DiskStation_Auth_SessionID"
        }
    }
}
