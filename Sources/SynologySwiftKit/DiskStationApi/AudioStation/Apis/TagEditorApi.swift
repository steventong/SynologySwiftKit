//
//  TagEditorApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

public final class TagEditorApi {
    private let apiClient: ApiRequestSending

    private static let TAG_EDITOR_URL = "/webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi"

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// 加载标签信息
    /// Load tag information
    /// - Throws: SynologyError.api(.tagEditorFailed) when operation fails
    public func load(path: String) async throws -> TagEditorDocument {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.TAG_EDITOR_UI, fullPath: Self.TAG_EDITOR_URL, httpMethod: .post) {
            ("action", "load")
            ("requestFrom", "")
            ("audioInfos", "[{\"path\":\"\(path)\"}]")
        }
        let result: TagEditorResult = try await apiClient.requestEnvelope(api)
        guard result.success else {
            throw SynologyError.api(code: -1, message: "query failed")
        }
        return TagEditorDocument(
            lyrics: result.lyrics,
            files: result.files,
            readFailedFileCount: result.readFailCount
        )
    }

    /// 应用标签修改
    /// Apply tag changes
    /// - Throws: SynologyError.api(.tagEditorFailed) when operation fails
    public func apply(update: TagEditorUpdate) async throws -> TagEditorDocument {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.TAG_EDITOR_UI, fullPath: Self.TAG_EDITOR_URL, httpMethod: .post) {
            ("action", "apply")
            ("requestFrom", "")
            ("data", JsonUtils.toJson(codable: [TagEditorRequest(update: update)]) ?? "")
        }
        let result: TagEditorResult = try await apiClient.requestEnvelope(api)
        guard result.success else {
            throw SynologyError.api(code: -1, message: "update failed")
        }
        return TagEditorDocument(
            lyrics: result.lyrics,
            files: result.files,
            readFailedFileCount: result.readFailCount
        )
    }
}
