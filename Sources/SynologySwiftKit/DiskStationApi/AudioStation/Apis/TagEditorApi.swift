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

    /// 更新指定文件的封面，并保留歌词和其他标签
    /// Update artwork for a file while preserving its lyrics and other tags
    /// - Parameters:
    ///   - artwork: 要设置的封面来源 / Artwork source to set
    ///   - path: Audio Station 中的歌曲绝对路径 / Absolute song path in Audio Station
    /// - Returns: 标签编辑器的保存结果 / Tag editor save result
    public func saveArtwork(_ artwork: TagEditorArtwork, forPath path: String) async throws -> TagEditorDocument {
        try await saveContent(forPath: path, lyrics: nil, artwork: artwork)
    }

    /// 更新指定文件的歌词，并可同时更新封面
    /// Update lyrics for a file and optionally update its artwork
    func saveLyrics(
        _ lyrics: String,
        forPath path: String,
        artwork: TagEditorArtwork
    ) async throws -> TagEditorDocument {
        try await saveContent(forPath: path, lyrics: lyrics, artwork: artwork)
    }

    private func saveContent(
        forPath path: String,
        lyrics: String?,
        artwork: TagEditorArtwork
    ) async throws -> TagEditorDocument {
        let document = try await load(path: path)
        guard document.readFailedFileCount == 0, let file = document.files.first else {
            throw SynologyError.api(code: -1, message: "failed to load tags before saving content")
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
            lyrics: lyrics ?? document.lyrics ?? "",
            track: file.track,
            disc: file.disc,
            year: file.year,
            artwork: artwork
        ))
    }
}
