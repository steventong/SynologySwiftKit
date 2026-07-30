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
        let audioInfos = try ApiParameterValue.jsonEncoded([
            TagEditorFileReference(path: path)
        ])
        let api = ApiEndpoint(api: SynologyApi.AudioStation.TAG_EDITOR_UI, fullPath: Self.TAG_EDITOR_URL, httpMethod: .post) {
            ("action", "load")
            ("requestFrom", "")
            ("audioInfos", audioInfos)
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
        let data = try ApiParameterValue.jsonEncoded([
            TagEditorRequest(update: update)
        ])
        let api = ApiEndpoint(api: SynologyApi.AudioStation.TAG_EDITOR_UI, fullPath: Self.TAG_EDITOR_URL, httpMethod: .post) {
            ("action", "apply")
            ("requestFrom", "")
            ("data", data)
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

    /// 仅更新指定文件的歌词，并保留其余标签和封面
    /// Update only the lyrics for a file while preserving its other tags and artwork
    func saveLyrics(_ lyrics: String, forPath path: String) async throws -> TagEditorDocument {
        let document = try await load(path: path)
        guard document.readFailedFileCount == 0, let file = document.files.first else {
            throw SynologyError.api(code: -1, message: "failed to load tags before saving lyrics")
        }

        return try await apply(update: TagEditorUpdate(
            files: [file],
            title: file.title,
            artist: file.artist,
            album: file.album,
            albumArtist: file.albumArtist,
            composer: file.composer,
            genre: file.genre,
            comment: file.comment,
            lyrics: lyrics,
            track: file.track,
            disc: file.disc,
            year: file.year,
            artwork: .originalImage
        ))
    }
}
