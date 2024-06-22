//
//  File.swift
//
//
//  Created by Steven on 2024/6/22.
//

import Foundation

/**
 {
   "success" : true,
   "data" : {
     "enable_equalizer" : false,
     "playing_queue_max" : 8192,
     "same_subnet" : false,
     "enable_user_home" : false,
     "has_aac" : false,
     "support_bluetooth" : false,
     "version_string" : "6.5.7-3383",
     "has_music_share" : true,
     "version" : 3383,
     "sid" : "x3nZxQ4hoK7yPEETQFqe9hvRu94vQP4lTN3X_pqf1t0P36M9gocTkx7rvqJCZlr7G3S468TXrrn1GD6oWB61lI",
     "enable_personal_library" : false,
     "settings" : {
       "disable_upnp" : false,
       "enable_download" : false,
       "transcode_to_mp3" : true,
       "prefer_using_html5" : true,
       "audio_show_virtual_library" : true
     },
     "support_usb" : false,
     "dsd_decode_capability" : true,
     "browse_personal_library" : "all",
     "serial_number" : "VW2C8A106HUIH",
     "privilege" : {
       "tag_edit" : false,
       "sharing" : false,
       "upnp_browse" : false,
       "playlist_edit" : false,
       "remote_player" : false
     },
     "support_virtual_library" : true,
     "remote_controller" : false,
     "transcode_capability" : [
       "wav",
       "mp3"
     ],
     "is_manager" : false
   }
 }
 */
public struct AudioStationInfo: Codable {
    public let enable_equalizer: Bool?
    public let playing_queue_max: Int?
    public let same_subnet: Bool?
    public let enable_user_home: Bool?
    public let has_aac: Bool?
    public let support_bluetooth: Bool?
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
    public let transcode_capability: [String]
    public let is_manager: Bool?
}

public struct AudioStationInfoSettings: Codable {
    public let disable_upnp: Bool?
    public let enable_download: Bool?
    public let transcode_to_mp3: Bool?
    public let prefer_using_html5: Bool?
    public let audio_show_virtual_library: Bool?
}

public struct AudioStationInfoPrivilege: Codable {
    public let tag_edit: Bool?
    public let sharing: Bool?
    public let upnp_browse: Bool?
    public let playlist_edit: Bool?
    public let remote_player: Bool?
}
