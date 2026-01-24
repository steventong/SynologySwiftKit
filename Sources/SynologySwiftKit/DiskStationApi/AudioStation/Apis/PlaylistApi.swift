//
//  PlaylistApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    /**
     query playlist list
     */
    public func playlistList(limit: Int, offset: Int) async throws -> (total: Int, data: [Playlist])
    {
        let result: PlaylistListResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "list",
                parameters: [
                    "library": "all",
                    "limit": limit,
                    "offset": offset,
                ]),
            resultType: PlaylistListResult.self
        )
        return (result.total, result.playlists)
    }

    /**
     query playlist songs
     */
    public func playlistSongList(
        id: String, library: String,
        additional: String = "songs_song_tag,songs_song_audio,songs_song_rating,sharing_info",
        limit: Int, offset: Int,
        sort: (sort_by: String, sort_direction: String)? = nil
    ) async throws -> (total: Int, data: [Song]) {
        let result: PlaylistGetInfoResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "getinfo", version: 3, httpMethod: .post,
                parameters: [
                    "id": id,
                    "library": library,
                    "additional": additional,
                    "songs_limit": limit,
                    "songs_offset": offset,
                ]),
            resultType: PlaylistGetInfoResult.self
        )
        if let playlist = result.playlists.first {
            return (playlist.songs_total, playlist.songs)
        }
        return (0, [])
    }

    /**
     创建播放列表
     */
    public func playlist_create(name: String, library: String, songs: String?) async throws
        -> String
    {
        let result: PlaylistCreateResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "create", version: 3, httpMethod: .post,
                parameters: [
                    "name": name,
                    "library": library,
                    "songs": songs ?? "",
                ]),
            resultType: PlaylistCreateResult.self
        )
        return result.id
    }

    /**
     创建智能播放列表
     */
    public func playlistCreateSmart(
        name: String, shared: Bool, conj_rule: String, rules_json: String
    ) async throws -> String? {
        let result: PlaylistCreateResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "createsmart", version: 2,
                httpMethod: .post,
                parameters: [
                    "name": name,
                    "library": shared ? "shared" : "personal",
                    "conj_rule": conj_rule,
                    "rules_json": rules_json,
                ]),
            resultType: PlaylistCreateResult.self
        )
        return result.id
    }

    /**
     重命名播放列表
     */
    public func playlist_rename(id: String, newName: String) async throws -> String? {
        let result: PlaylistRenameResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "rename", version: 3, httpMethod: .post,
                parameters: [
                    "id": id,
                    "new_name": newName,
                ]),
            resultType: PlaylistRenameResult.self
        )
        return result.id
    }

    /**
     删除播放列表
     */
    public func playlist_delete(id: String) async throws -> Bool {
        let result: PlaylistDeleteResult = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "delete", version: 3, httpMethod: .post,
                parameters: ["id": id]),
            resultType: PlaylistDeleteResult.self
        )
        return result.errors.isEmpty
    }

    /**
     移除丢失歌曲
     */
    public func playlistRemoveMissing(id: String) async throws -> Bool {
        try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "removemissing", version: 3,
                httpMethod: .post, parameters: ["id": id])
        )
        return true
    }

    /**
     添加歌曲到播放列表
     */
    public func playlistAddSongs(id: String, songs: [String]) async throws -> Bool {
        var parameters: [String: Any] = [
            "id": id,
            "limit": 0,
            "offset": -1,
            "skip_duplicate": true,
        ]
        if !songs.isEmpty {
            parameters["songs"] = songs.joined(separator: ",")
        }

        try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "updatesongs", version: 3,
                httpMethod: .post, parameters: parameters)
        )
        return true
    }
}
