//
//  File.swift
//
//
//  Created by Steven on 2024/4/28.
//

import Foundation

enum UserDefaultsKeys {
    case SYNOLOGY_SERVER_URL(String)

    case DISK_STATION_SERVER
    case DISK_STATION_SERVER_ENABLE_HTTPS

    case DISK_STATION_CONNECTION_URL
    case DISK_STATION_CONNECTION_TYPE

    case DISK_STATION_AUTH_DEVICE_NAME
    case DISK_STATION_AUTH_DEVICE_ID

    case DISK_STATION_AUTH_SESSION_SID
    case DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT
    case DISK_STATION_AUTH_SESSION_DID
    case DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT

    case DISK_STATION_API_INFO
    case DISK_STATION_API_INFO_UPDATE_TIME

    var keyName: String {
        switch self {
        case let .SYNOLOGY_SERVER_URL(quickConnectId):
            return "SynologySwiftKit_SynologyServer_\(quickConnectId)"
        case let .DISK_STATION_SERVER:
            return "SynologySwiftKit_DiskStation_Server"
        case let .DISK_STATION_SERVER_ENABLE_HTTPS:
            return "SynologySwiftKit_DiskStation_ServerEnableHttps"
        case .DISK_STATION_CONNECTION_URL:
            return "SynologySwiftKit_DiskStation_ConnectionURL"
        case .DISK_STATION_CONNECTION_TYPE:
            return "SynologySwiftKit_DiskStation_ConnectionType"
        case .DISK_STATION_AUTH_DEVICE_NAME:
            return "SynologySwiftKit_DiskStation_Auth_DeviceName"
        case .DISK_STATION_AUTH_DEVICE_ID:
            return "SynologySwiftKit_DiskStation_Auth_DeviceID"
        case .DISK_STATION_AUTH_SESSION_SID:
            return "SynologySwiftKit_DiskStation_Auth_Session_SID"
        case .DISK_STATION_AUTH_SESSION_SID_EXPIRE_AT:
            return "SynologySwiftKit_DiskStation_Auth_Session_SID_expireAt"
        case .DISK_STATION_AUTH_SESSION_DID:
            return "SynologySwiftKit_DiskStation_Auth_Session_DID"
        case .DISK_STATION_AUTH_SESSION_DID_EXPIRE_AT:
            return "SynologySwiftKit_DiskStation_Auth_Session_DID_expireAt"
        case .DISK_STATION_API_INFO:
            return "SynologySwiftKit_DiskStation_Api_Info"
        case .DISK_STATION_API_INFO_UPDATE_TIME:
            return "SynologySwiftKit_DiskStation_Api_Info_updateTime"
        }
    }
}
