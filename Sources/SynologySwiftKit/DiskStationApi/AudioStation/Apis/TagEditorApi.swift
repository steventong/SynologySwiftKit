//
//  TagEditorApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    public func tagEditor_load(path: String) async throws -> TagEditorResult? {
        let result: TagEditorResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.TAG_EDITOR_UI,
                customPath: "/webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi",
                httpMethod: .post,
                parameters: [
                    "action": "load",
                    "requestFrom": "",
                    "audioInfos": "[{\"path\":\"\(path)\"}]",
                ]
            ),
            rawResponse: true
        )
        return result.success ? result : nil
    }

    public func tagEditor_apply(request: TagEditorRequest) async throws -> TagEditorResult? {
        let result: TagEditorResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.TAG_EDITOR_UI,
                customPath: "/webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi",
                httpMethod: .post,
                parameters: [
                    "action": "apply",
                    "requestFrom": "",
                    "data": JsonUtils.toJson(codable: [request]) ?? "",
                ]
            ),
            rawResponse: true
        )
        return result.success ? result : nil
    }
}
