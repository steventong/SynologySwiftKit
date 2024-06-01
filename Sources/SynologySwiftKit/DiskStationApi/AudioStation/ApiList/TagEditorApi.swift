//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

class TagEditorApi {
    public init() {
    }

    /**
     query song list

     /webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi?action=load&audioInfos=[{"path":"/music/五月天/离开地球表面/10 阿姆斯壮 Live.flac"}]&requestFrom=&_sid=mYq4456W8YQOpXTJogD_2sz8CSXtiOjEQXqNsLEXQE8ZtD1ajc0PQT1k5ucI8bmDmcAnZifrjfs1fzIuGWQLGk

     {
         "files": [
             {
                 "album": "离开地球表面",
                 "album_artist": "五月天",
                 "artist": "五月天",
                 "comment": "",
                 "composer": "",
                 "disc": 1,
                 "genre": "",
                 "path": "/music/五月天/离开地球表面/10 阿姆斯壮 Live.flac",
                 "title": "阿姆斯壮 Live",
                 "track": 10,
                 "year": 2007
             }
         ],
         "lyrics": "",
         "read_fail_count": 0,
         "success": true
     }

     */
    public func load(path: String) async throws -> TagEditorResult? {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw SynoDiskStationApiError.invalidSession
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_TAG_EDITOR_UI, method: "load", parameters: [
            "action": "load",
            "requestFrom": "",
            "audioInfos": "[{\"path\":\"\(path)\"}]",
            "_sid": sid,
        ])

        do {
            let result = try await api.requestForResult(resultType: TagEditorResult.self)
            if result.success {
                return result
            }
        } catch {
            Logger.error("TagEditorApi.load error: \(error)")
        }

        return nil
    }
}
