//
//  TagEditorApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

public final class TagEditorApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    public func load(path: String) async throws -> TagEditorResult? {
        let result: TagEditorResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.TAG_EDITOR_UI,
                customPath: "/webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi",
                httpMethod: .post
            ) {
                ("action", "load")
                ("requestFrom", "")
                ("audioInfos", "[{\"path\":\"\(path)\"}]")
            },
            rawResponse: true
        )
        return result.success ? result : nil
    }

    public func apply(request: TagEditorRequest) async throws -> TagEditorResult? {
        let result: TagEditorResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.TAG_EDITOR_UI,
                customPath: "/webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi",
                httpMethod: .post
            ) {
                ("action", "apply")
                ("requestFrom", "")
                ("data", JsonUtils.toJson(codable: [request]) ?? "")
            },
            rawResponse: true
        )
        return result.success ? result : nil
    }
}
