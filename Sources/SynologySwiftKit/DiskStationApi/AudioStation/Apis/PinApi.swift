//
//  PinApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

extension AudioStationApi {
    
    /// 获取固定列表
    /// Get pinned items list
    /// - Parameters:
    ///   - limit: 每页数量，-1 表示全部
    ///   - offset: 偏移量
    /// - Returns: 总数和固定项列表
    public func pinList(limit: Int = -1, offset: Int = 0) async throws -> (total: Int, items: [PinItem]) {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PIN, method: "list", version: 1, parameters: [
            "offset": offset,
            "limit": limit
        ])
        
        let result = try await api.requestForData(resultType: PinListResult.self)
        return (result.total, result.items)
    }
    
    /// 固定专辑
    /// Pin an album
    /// - Parameters:
    ///   - album: 专辑名称
    ///   - albumArtist: 专辑艺术家
    /// - Returns: 固定后的项目
    public func pinAlbum(album: String, albumArtist: String) async throws -> PinItem? {
        let item: [[String: Any]] = [
            [
                "type": "album",
                "criteria": [
                    "album": album,
                    "album_artist": albumArtist
                ],
                "name": album
            ]
        ]
        
        let itemsJSON = try JSONSerialization.data(withJSONObject: item)
        let itemsString = String(data: itemsJSON, encoding: .utf8) ?? "[]"
        
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PIN, method: "pin", version: 1, httpMethod: .post, parameters: [
            "items": itemsString
        ])
        
        let result = try await api.requestForData(resultType: PinOperationResult.self)
        return result.items.first
    }
}
