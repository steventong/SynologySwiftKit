//
//  TagEditorApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    public func tagEditor_load(path: String) async throws -> TagEditorResult? {
        let result: TagEditorResult = try await apiClient.requestForResult(
            ApiEndpoint(
                api: SynologyApi.AudioStation.tagEditorUI,
                customPath: "/webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi",
                httpMethod: .post,
                parameters: [
                    "action": "load",
                    "requestFrom": "",
                    "audioInfos": "[{\"path\":\"\(path)\"}]",
                ]
            ),
            resultType: TagEditorResult.self
        )
        return result.success ? result : nil
    }

    public func tagEditor_apply(request: TagEditorRequest) async throws -> TagEditorResult? {
        let result: TagEditorResult = try await apiClient.requestForResult(
            ApiEndpoint(
                api: SynologyApi.AudioStation.tagEditorUI,
                customPath: "/webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi",
                httpMethod: .post,
                parameters: [
                    "action": "apply",
                    "requestFrom": "",
                    "data": JsonUtils.toJson(codable: [request]) ?? "",
                ]
            ),
            resultType: TagEditorResult.self
        )
        return result.success ? result : nil
    }
}
