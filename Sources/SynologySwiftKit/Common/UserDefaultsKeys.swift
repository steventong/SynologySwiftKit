//

//
//
//  Created by Steven on 2024/4/28.
//

import Foundation

enum UserDefaultsKeys {
    case SYNOLOGY_SERVER_URL(String)

    case DISK_STATION_API_INFO
    case DISK_STATION_API_INFO_UPDATE_TIME

    case DISK_STATION_AUDIO_STATION_INFO
    case DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME

    var keyName: String {
        switch self {
        case let .SYNOLOGY_SERVER_URL(quickConnectId):
            return "SynologySwiftKit_SynologyServer_\(quickConnectId)"
        case .DISK_STATION_API_INFO:
            return "SynologySwiftKit_DiskStation_ApiInfo"
        case .DISK_STATION_API_INFO_UPDATE_TIME:
            return "SynologySwiftKit_DiskStation_ApiInfo_updateTime"
        case .DISK_STATION_AUDIO_STATION_INFO:
            return "SynologySwiftKit_DiskStation_AudioStation_Info"
        case .DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME:
            return "SynologySwiftKit_DiskStation_AudioStation_updateTime"
        }
    }
}
