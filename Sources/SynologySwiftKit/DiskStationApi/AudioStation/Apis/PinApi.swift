//
//  PinApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - Pin API

/// AudioStation 固定 API（依赖注入）
/// AudioStation Pin API (dependency injection)
public final class PinApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// 分页读取固定项。
    ///
    /// GET SYNO.AudioStation.Pin/list，声明版本 1。
    ///
    /// - Parameters:
    ///   - limit: 默认 -1，表示请求全部固定项。
    ///   - offset: 起始偏移，默认 0。
    /// - Returns: SynologyPage<PinItem>，来自 data.total/items。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func list(limit: Int = -1, offset: Int = 0) async throws -> SynologyPage<PinItem> {
        let result: PinListResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.PIN, method: "list") {
                ("offset", offset)
                ("limit", limit)
            }
        )
        return SynologyPage(total: result.total, items: result.items)
    }

    /// 固定一个目录或标签条件。
    ///
    /// POST SYNO.AudioStation.Pin/pin，声明版本 1。
    ///
    /// 失败 envelope 的 code=1002 且 errors 包含 1006 时视为已经固定。顶层成功时返回首项，当前实现没有进一步校验 data.errors。
    ///
    /// - Parameters:
    ///   - type: folder/album/artist/composer/genre/playlist；playlist 仅有模型枚举，没有便捷固定方法。
    ///   - name: 固定项显示名称。
    ///   - criteria: 与类型对应的筛选条件；连同 type/name 编为单元素 JSON 数组字符串 items。
    /// - Returns: PinCreationResult.created（首个返回项）或 alreadyExists。
    /// - Throws: 请求错误；成功但缺少首项时抛出 SynologyError.api(code: -1)；其他失败转换为 SynologyError。
    public func pin(type: PinType, name: String, criteria: PinCriteria) async throws -> PinCreationResult {
        let itemsString = try ApiParameterValue.jsonEncoded([PinRequestItem(type: type, criteria: criteria, name: name)]).stringValue

        let api = ApiEndpoint(api: SynologyApi.AudioStation.PIN, method: "pin", httpMethod: .post) {
            ("items", itemsString)
        }
        let response: SynologyResponse<PinOperationResult> = try await apiClient.requestEnvelope(api)

        if response.success {
            guard let result = response.data, let pinItem = result.items.first else {
                throw SynologyError.api(code: -1, message: "pin failed")
            }
            return .created(pinItem)
        }

        if let error = response.error {
            // Pin API: 1002 + 1006 means "already pinned", treat as idempotent success.
            if error.code == 1002, error.errors.contains(1006) {
                return .alreadyExists
            }
            throw error.toSynologyError()
        }

        throw SynologyError.api(code: -1, message: "pin failed")
    }

    /// 取消固定
    /// Unpin items by IDs
    @discardableResult
    /// 取消一组固定项。
    ///
    /// POST SYNO.AudioStation.Pin/unpin，声明版本 1。
    ///
    /// - Parameters:
    ///   - ids: 固定项 ID 数组，编码为 JSON 字符串 items；不是歌曲 ID。
    /// - Returns: PinRemovalResult，含 removedIDs 和 failures；须检查逐项失败。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func unpin(ids: [String]) async throws -> PinRemovalResult {
        let itemsString = try ApiParameterValue.jsonEncoded(ids).stringValue

        let result: UnpinOperationResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.PIN, method: "unpin", httpMethod: .post) {
                ("items", itemsString)
            }
        )
        return PinRemovalResult(removedIDs: result.items, failures: result.errors)
    }
}

// MARK: - Convenience Methods

extension PinApi {
    /// 使用预设类型和条件固定项目。
    ///
    /// 委托 pin(type:name:criteria:)；POST Pin/pin v1。
    ///
    /// 使用 type=folder。
    ///
    /// - Parameters:
    ///   - folderId: 文件夹 ID，写入 criteria.folder。
    ///   - name: 固定项显示名称。
    /// - Returns: PinCreationResult，语义和错误处理与 pin 相同。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func pinFolder(folderId: String, name: String) async throws -> PinCreationResult {
        try await pin(type: .folder, name: name, criteria: .folder(folderId))
    }

    /// 使用预设类型和条件固定项目。
    ///
    /// 委托 pin(type:name:criteria:)；POST Pin/pin v1。
    ///
    /// 使用 type=album，条件包含 album 和 album_artist。
    ///
    /// - Parameters:
    ///   - album: 专辑名称，同时作为固定项名称。
    ///   - albumArtist: 专辑艺术家，默认空字符串。
    /// - Returns: PinCreationResult，语义和错误处理与 pin 相同。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func pinAlbum(album: String, albumArtist: String = "") async throws -> PinCreationResult {
        try await pin(type: .album, name: album, criteria: .album(album, albumArtist: albumArtist))
    }

    /// 使用预设类型和条件固定项目。
    ///
    /// 委托 pin(type:name:criteria:)；POST Pin/pin v1。
    ///
    /// 使用 type=artist 和同名筛选条件。
    ///
    /// - Parameters:
    ///   - artist: 艺术家名称。
    /// - Returns: PinCreationResult，语义和错误处理与 pin 相同。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func pinArtist(artist: String) async throws -> PinCreationResult {
        try await pin(type: .artist, name: artist, criteria: .artist(artist))
    }

    /// 使用预设类型和条件固定项目。
    ///
    /// 委托 pin(type:name:criteria:)；POST Pin/pin v1。
    ///
    /// 使用 type=composer 和同名筛选条件。
    ///
    /// - Parameters:
    ///   - composer: 作曲家名称。
    /// - Returns: PinCreationResult，语义和错误处理与 pin 相同。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func pinComposer(composer: String) async throws -> PinCreationResult {
        try await pin(type: .composer, name: composer, criteria: .composer(composer))
    }

    /// 使用预设类型和条件固定项目。
    ///
    /// 委托 pin(type:name:criteria:)；POST Pin/pin v1。
    ///
    /// 使用 type=genre 和同名筛选条件。
    ///
    /// - Parameters:
    ///   - genre: 流派名称。
    /// - Returns: PinCreationResult，语义和错误处理与 pin 相同。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func pinGenre(genre: String) async throws -> PinCreationResult {
        try await pin(type: .genre, name: genre, criteria: .genre(genre))
    }
}
