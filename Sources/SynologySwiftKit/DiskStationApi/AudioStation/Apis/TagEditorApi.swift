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

    /// 读取歌曲文件的标签和歌词。
    ///
    /// POST /webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi，action=load。
    ///
    /// requestFrom 为空；这是自定义顶层响应，不是标准 WebAPI data envelope。应检查 readFailedFileCount。
    ///
    /// - Parameters:
    ///   - path: NAS 上歌曲绝对路径，JSON 编码为 audioInfos=[{path: ...}]。
    /// - Returns: TagEditorDocument，含 lyrics/files/readFailedFileCount。
    /// - Throws: 请求/解码错误；success=false 时抛出 SynologyError.api(code: -1)，消息来自 error_msg。
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
            throw SynologyError.api(code: -1, message: result.errorMessage ?? "query failed")
        }
        return TagEditorDocument(
            lyrics: result.lyrics,
            files: result.files,
            readFailedFileCount: result.readFailCount
        )
    }

    /// 提交完整文件标签。
    ///
    /// POST /webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi，action=apply。
    ///
    /// 这是完整提交，不是局部补丁。track/disc/year 转为字符串，nil 编为空串；artwork=nil 时 coverType/coverPath 为空串。保留封面应显式使用 originalImage。
    ///
    /// - Parameters:
    ///   - update: 完整标签及原始 files；编码为单元素 JSON 数组 data，requestFrom 为空。
    /// - Returns: TagEditorDocument；当前模型不暴露 write_fail_files，不能据此确认逐文件成功。
    /// - Throws: 请求/解码错误；success=false 时抛出 SynologyError.api(code: -1)，消息来自 error_msg。
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
            throw SynologyError.api(code: -1, message: result.errorMessage ?? "update failed")
        }
        return TagEditorDocument(
            lyrics: result.lyrics,
            files: result.files,
            readFailedFileCount: result.readFailCount
        )
    }

    /// 先读取完整标签，再更新封面。
    ///
    /// 标签编辑 CGI 的 load → apply 两次 POST。
    ///
    /// 远程封面地址受 NAS 的网络访问和 SSRF 限制；需当前用户具有标签编辑权限。
    ///
    /// - Parameters:
    ///   - artwork: 保留原图、NAS 图片路径或远程图片 URL；远程图片由 NAS 下载。
    ///   - path: 歌曲绝对路径。
    /// - Returns: TagEditorDocument，保留加载的歌词及其他标签。
    /// - Throws: 读取失败、无首个文件或写入被拒绝时抛出 SynologyError；其他请求错误向上传递。
    public func saveArtwork(_ artwork: TagEditorArtwork, forPath path: String) async throws -> TagEditorDocument {
        try await saveContent(forPath: path, lyrics: nil, artwork: artwork)
    }

    /// 更新指定文件的歌词，不修改封面
    /// Update lyrics for a file without modifying its artwork
    func saveLyrics(_ lyrics: String, forPath path: String) async throws -> TagEditorDocument {
        try await saveContent(forPath: path, lyrics: lyrics, artwork: .originalImage)
    }

    private func saveContent(
        forPath path: String,
        lyrics: String?,
        artwork: TagEditorArtwork?
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
