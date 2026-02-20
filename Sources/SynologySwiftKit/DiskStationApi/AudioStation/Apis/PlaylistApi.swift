//
//  PlaylistApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

public final class PlaylistApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     query playlist list
     */
    public func list(limit: Int, offset: Int) async throws -> (total: Int, data: [Playlist]) {
        let result: PlaylistListResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.PLAYLIST, method: "list") {
                ("library", "all")
                ("limit", limit)
                ("offset", offset)
            }
        )
        return (result.total, result.playlists)
    }

    /**
     query playlist songs
     */
    public func getSongs(id: String, library: String,
                         additional: String = "songs_song_tag,songs_song_audio,songs_song_rating,sharing_info",
                         limit: Int, offset: Int,
                         sort: (sort_by: String, sort_direction: String)? = nil) async throws -> (total: Int, data: [Song]) {
        let result: PlaylistGetInfoResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "getinfo", version: 3,
                httpMethod: .post) {
                    ("id", id)
                    ("library", library)
                    ("additional", additional)
                    ("songs_limit", limit)
                    ("songs_offset", offset)
                }
        )
        if let playlist = result.playlists.first {
            return (playlist.songsTotal, playlist.songs)
        }
        return (0, [])
    }

    /**
     创建播放列表
     */
    public func create(name: String, library: String, songs: String?) async throws -> String {
        let result: PlaylistCreateResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.PLAYLIST, method: "create", version: 3, httpMethod: .post) {
                ("name", name)
                ("library", library)
                ("songs", songs ?? "")
            }
        )
        return result.id
    }

    /**
     创建智能播放列表
     Create smart playlist
     - Throws: SynologyError.api(.playlistOperationFailed) when operation fails
     */
    public func createSmart(
        name: String, shared: Bool, conj_rule: String, rules_json: String
    ) async throws -> String {
        let result: PlaylistCreateResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "createsmart", version: 2,
                httpMethod: .post) {
                    ("name", name)
                    ("library", shared ? "shared" : "personal")
                    ("conj_rule", conj_rule)
                    ("rules_json", rules_json)
                }
        )
        return result.id
    }

    /**
     重命名播放列表
     Rename playlist
     - Throws: SynologyError.api(.playlistOperationFailed) when operation fails
     */
    public func rename(id: String, newName: String) async throws -> String {
        let result: PlaylistRenameResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "rename", version: 3,
                httpMethod: .post) {
                    ("id", id)
                    ("new_name", newName)
                }
        )
        return result.id
    }

    /**
     删除播放列表
     */
    public func delete(id: String) async throws -> Bool {
        let result: PlaylistDeleteResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "delete", version: 3,
                httpMethod: .post
            ) {
                ("id", id)
            }
        )
        return result.errors.isEmpty
    }

    /**
     移除丢失歌曲
     */
    public func removeMissing(id: String) async throws -> Bool {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.PLAYLIST, method: "removemissing", version: 3,
            httpMethod: .post) {
                ("id", id)
            }
        let _: EmptyData = try await apiClient.request(api)
        return true
    }

    /**
     添加歌曲到播放列表
     */
    public func addSongs(id: String, songs: [String]) async throws -> Bool {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.PLAYLIST, method: "updatesongs", version: 3,
            httpMethod: .post) {
                ("id", id)
                ("limit", 0)
                ("offset", -1)
                ("skip_duplicate", true)
                if !songs.isEmpty {
                    ("songs", songs.joined(separator: ","))
                }
            }
        let _: EmptyData = try await apiClient.request(api)
        return true
    }
}
