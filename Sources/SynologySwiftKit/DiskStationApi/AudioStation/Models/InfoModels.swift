//

//
//
//  Created by Steven on 2024/6/22.
//

import Foundation

// MARK: - AudioStationInfo

/// AudioStation 系统信息（由 `SYNO.AudioStation.Info getinfo` 接口返回）
/// AudioStation system info (returned by `SYNO.AudioStation.Info getinfo`)
public struct AudioStationInfo: Codable, Sendable {
    public let enable_equalizer: Bool?
    public let playing_queue_max: Int?
    public let same_subnet: Bool?
    public let enable_user_home: Bool?
    public let has_aac: Bool?
    public let support_bluetooth: Bool?
    /// 版本字符串（如 "6.5.7-3383"）/ Version string (e.g. "6.5.7-3383")
    public let version_string: String?
    public let has_music_share: Bool?
    public let version: Int?
    public let sid: String?
    public let enable_personal_library: Bool?

    public let settings: AudioStationInfoSettings

    public let support_usb: Bool?
    public let dsd_decode_capability: Bool?
    public let browse_personal_library: String?
    public let serial_number: String?

    public let privilege: AudioStationInfoPrivilege

    public let support_virtual_library: Bool?
    public let remote_controller: Bool?
    /// 支持的转码格式列表（如 ["wav", "mp3"]）/ Supported transcode formats (e.g. ["wav", "mp3"])
    public let transcode_capability: [String]
    public let is_manager: Bool?
}

// MARK: - AudioStationInfoSettings

/// AudioStation 设置项
/// AudioStation settings
public struct AudioStationInfoSettings: Codable, Sendable {
    public let disable_upnp: Bool?
    public let enable_download: Bool?
    public let transcode_to_mp3: Bool?
    public let prefer_using_html5: Bool?
    public let audio_show_virtual_library: Bool?
}

// MARK: - AudioStationInfoPrivilege

/// AudioStation 当前用户权限
/// AudioStation current user privileges
public struct AudioStationInfoPrivilege: Codable, Sendable {
    public let tag_edit: Bool?
    public let sharing: Bool?
    public let upnp_browse: Bool?
    public let playlist_edit: Bool?
    public let remote_player: Bool?
}
