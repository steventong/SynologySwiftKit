//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
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
    public func tagEditor_load(path: String) async throws -> TagEditorResult? {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_TAG_EDITOR_UI, method: "load", httpMethod: .post, parameters: [
            "action": "load",
            "requestFrom": "",
            "audioInfos": "[{\"path\":\"\(path)\"}]",
        ])

        let result = try await api.requestForResult(resultType: TagEditorResult.self)
        if result.success {
            return result
        }

        return nil
    }

    /**
     POST  /webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi

     action: apply
     data: [{"audioInfos":[{"album":"最偉大的作品","album_artist":"周杰倫","artist":"周杰倫","comment":"","composer":"","disc":1,"genre":"Pop","path":"/music/周杰倫 - 最偉大的作品 (2022) [FLAC]/08. 錯過的煙火.flac","title":"錯過的煙火","track":8,"year":2022}],"lyrics":"","coverType":"original_image","coverPath":"","title":"错过的烟火","artist":"周杰倫","album":"最偉大的作品","comment":"","genre":"Pop","track":"8","disc":"1","year":"2022","album_artist":"周杰倫","composer":"","codePage":"SYNO_NO_CODE_PAGE_CONVERT"}]
     requestFrom:
     */
    public func tagEditor_apply(request: TagEditorRequest) async throws -> TagEditorResult? {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_TAG_EDITOR_UI, method: "apply", httpMethod: .post, parameters: [
            "action": "apply",
            "requestFrom": "",
            "audioInfos": JsonUtils.toJson(codable: request) ?? "",
        ])
        let result = try await api.requestForResult(resultType: TagEditorResult.self)
        if result.success {
            return result
        }

        return nil
    }
}
