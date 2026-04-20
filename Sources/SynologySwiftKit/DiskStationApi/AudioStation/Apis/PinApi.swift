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
    private let apiClient: ApiClientProviding

    init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /// 获取固定列表
    /// Get pinned items list
    public func list(limit: Int = -1, offset: Int = 0) async throws -> SynologyPage<PinItem> {
        let result: PinListResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.PIN, method: "list", parameters: ["offset": offset, "limit": limit])
        )
        return SynologyPage(total: result.total, items: result.items)
    }

    /// 固定项目（通用方法）
    /// Pin an item
    /// - Throws: SynologyError.api(.idempotentSuccess) when item already pinned
    public func pin(type: PinType, name: String, criteria: PinCriteria) async throws -> PinItem {
        let item: [[String: Any]] = [
            [
                "type": type.rawValue,
                "criteria": criteria.toDictionary(),
                "name": name,
            ],
        ]

        let itemsJSON = try JSONSerialization.data(withJSONObject: item)
        let itemsString = String(data: itemsJSON, encoding: .utf8) ?? "[]"

        let api = ApiEndpoint(api: SynologyApi.AudioStation.PIN, method: "pin", httpMethod: .post, parameters: ["items": itemsString])
        let response: SynologyResponse<PinOperationResult> = try await apiClient.request(api, rawResponse: true)

        if response.success {
            guard let result = response.data, let pinItem = result.items.first else {
                throw SynologyError.api(code: -1, message: "pin failed")
            }
            return pinItem
        }

        if let error = response.error {
            // Pin API: 1002 + 1006 means "already pinned", treat as idempotent success.
            if error.code == 1002, error.errors.contains(1006) {
                throw SynologyError.api(code: 0, message: "pin already exists")
            }
            throw error.toSynologyError()
        }

        throw SynologyError.api(code: -1, message: "pin failed")
    }

    /// 取消固定
    /// Unpin items by IDs
    @discardableResult
    public func unpin(ids: [String]) async throws -> PinRemovalResult {
        let itemsJSON = try JSONSerialization.data(withJSONObject: ids)
        let itemsString = String(data: itemsJSON, encoding: .utf8) ?? "[]"

        let result: UnpinOperationResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.PIN, method: "unpin", httpMethod: .post, parameters: ["items": itemsString])
        )
        return PinRemovalResult(removedIDs: result.items, failures: result.errors)
    }
}

// MARK: - Convenience Methods

extension PinApi {
    /// 固定文件夹
    public func pinFolder(folderId: String, name: String) async throws -> PinItem {
        try await pin(type: .folder, name: name, criteria: .folder(folderId))
    }

    /// 固定专辑
    public func pinAlbum(album: String, albumArtist: String = "") async throws -> PinItem {
        try await pin(type: .album, name: album, criteria: .album(album, albumArtist: albumArtist))
    }

    /// 固定艺术家
    public func pinArtist(artist: String) async throws -> PinItem {
        try await pin(type: .artist, name: artist, criteria: .artist(artist))
    }

    /// 固定作曲家
    public func pinComposer(composer: String) async throws -> PinItem {
        try await pin(type: .composer, name: composer, criteria: .composer(composer))
    }

    /// 固定流派
    public func pinGenre(genre: String) async throws -> PinItem {
        try await pin(type: .genre, name: genre, criteria: .genre(genre))
    }
}
