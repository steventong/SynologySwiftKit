//
//  PinApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - Pin API

/// AudioStation 固定 API
/// AudioStation Pin API
public final class PinApi {
    
    public init() {}
    
    /// 获取固定列表
    /// Get pinned items list
    /// - Parameters:
    ///   - limit: 每页数量，-1 表示全部
    ///   - offset: 偏移量
    /// - Returns: 总数和固定项列表
    public func list(limit: Int = -1, offset: Int = 0) async throws -> (total: Int, items: [PinItem]) {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PIN, method: "list", version: 1, parameters: [
            "offset": offset,
            "limit": limit
        ])
        
        let result: PinListResult = try await api.fetch()
        return (result.total, result.items)
    }
    
    /// 固定项目（通用方法）
    /// Pin an item
    /// - Parameters:
    ///   - type: 固定类型
    ///   - name: 显示名称
    ///   - criteria: 筛选条件
    /// - Returns: 固定后的项目
    /// - Throws: SynologyError（如 code=1006 表示已固定）
    public func pin(type: PinType, name: String, criteria: PinCriteria) async throws -> PinItem? {
        let item: [[String: Any]] = [
            [
                "type": type.rawValue,
                "criteria": criteria.toDictionary(),
                "name": name
            ]
        ]
        
        let itemsJSON = try JSONSerialization.data(withJSONObject: item)
        let itemsString = String(data: itemsJSON, encoding: .utf8) ?? "[]"
        
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PIN, method: "pin", version: 1, httpMethod: .post, parameters: [
            "items": itemsString
        ])
        
        let result: PinOperationResult = try await api.fetch()
        return result.items.first
    }
    
    /// 取消固定
    /// Unpin items by IDs
    /// - Parameter ids: 要取消固定的项目 ID 列表
    /// - Returns: 操作结果，包含成功和失败的详情
    @discardableResult
    public func unpin(ids: [String]) async throws -> UnpinOperationResult {
        let itemsJSON = try JSONSerialization.data(withJSONObject: ids)
        let itemsString = String(data: itemsJSON, encoding: .utf8) ?? "[]"
        
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PIN, method: "unpin", version: 1, httpMethod: .post, parameters: [
            "items": itemsString
        ])
        
        return try await api.fetch()
    }
}

// MARK: - Convenience Methods

extension PinApi {
    
    /// 固定文件夹
    public func pinFolder(folderId: String, name: String) async throws -> PinItem? {
        try await pin(type: .folder, name: name, criteria: .folder(folderId))
    }
    
    /// 固定专辑
    public func pinAlbum(album: String, albumArtist: String = "") async throws -> PinItem? {
        try await pin(type: .album, name: album, criteria: .album(album, albumArtist: albumArtist))
    }
    
    /// 固定艺术家
    public func pinArtist(artist: String) async throws -> PinItem? {
        try await pin(type: .artist, name: artist, criteria: .artist(artist))
    }
    
    /// 固定作曲家
    public func pinComposer(composer: String) async throws -> PinItem? {
        try await pin(type: .composer, name: composer, criteria: .composer(composer))
    }
    
    /// 固定流派
    public func pinGenre(genre: String) async throws -> PinItem? {
        try await pin(type: .genre, name: genre, criteria: .genre(genre))
    }
}
