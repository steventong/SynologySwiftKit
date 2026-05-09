//
//  PlaylistApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

public final class PlaylistApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /**
     query playlist list
     */
    public func list(limit: Int, offset: Int) async throws -> SynologyPage<Playlist> {
        let result: PlaylistListResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.PLAYLIST, method: "list") {
                ("library", "all")
                ("limit", limit)
                ("offset", offset)
            }
        )
        return SynologyPage(total: result.total, items: result.playlists)
    }

    /**
     query playlist songs
     */
    public func getSongs(id: String, libraryScope: SynologyLibraryScope,
                         includeFields: String = "songs_song_tag,songs_song_audio,songs_song_rating,sharing_info",
                         limit: Int, offset: Int,
                         sort: SynologySortDescriptor? = nil) async throws -> SynologyPage<Song> {
        let result: PlaylistGetInfoResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "getinfo", version: 3,
                httpMethod: .post) {
                    ("id", id)
                    ("library", libraryScope.rawValue)
                    ("additional", includeFields)
                    ("songs_limit", limit)
                    ("songs_offset", offset)
                }
        )
        if let playlist = result.playlists.first {
            return SynologyPage(total: playlist.songsTotal, items: playlist.songs)
        }
        return SynologyPage(total: 0, items: [])
    }

    /**
     创建播放列表
     */
    public func create(name: String, libraryScope: SynologyLibraryScope, songIDs: [String] = []) async throws -> PlaylistReference {
        let result: PlaylistCreateResult = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.PLAYLIST, method: "create", version: 3, httpMethod: .post) {
                ("name", name)
                ("library", libraryScope.rawValue)
                if !songIDs.isEmpty {
                    ("songs", songIDs.joined(separator: ","))
                }
            }
        )
        return PlaylistReference(id: result.id)
    }

    /**
     创建智能播放列表
     Create smart playlist
     - Throws: SynologyError.api(.playlistOperationFailed) when operation fails
     */
    public func createSmart(name: String, definition: SmartPlaylistDefinition) async throws -> PlaylistReference {
        let result: PlaylistCreateResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "createsmart", version: 2,
                httpMethod: .post) {
                    ("name", name)
                    ("library", definition.scope.rawValue)
                    ("conj_rule", definition.matchRule.rawValue)
                    ("rules_json", definition.serializedRules)
                }
        )
        return PlaylistReference(id: result.id)
    }

    /**
     重命名播放列表
     Rename playlist
     - Throws: SynologyError.api(.playlistOperationFailed) when operation fails
     */
    public func rename(id: String, name: String) async throws -> PlaylistReference {
        let result: PlaylistRenameResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "rename", version: 3,
                httpMethod: .post) {
                    ("id", id)
                    ("new_name", name)
                }
        )
        return PlaylistReference(id: result.id)
    }

    /**
     删除播放列表
     */
    public func delete(id: String) async throws -> PlaylistDeletionResult {
        let result: PlaylistDeleteResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "delete", version: 3,
                httpMethod: .post
            ) {
                ("id", id)
            }
        )
        return PlaylistDeletionResult(requestedID: id, failedItemIDs: result.errors)
    }

    /**
     移除丢失歌曲
     */
    public func removeMissing(id: String) async throws -> PlaylistMutationResult {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.PLAYLIST, method: "removemissing", version: 3,
            httpMethod: .post) {
                ("id", id)
            }
        let _: EmptyData = try await apiClient.request(api)
        return PlaylistMutationResult(playlistID: id)
    }

    /**
     添加歌曲到播放列表
     */
    public func addSongs(id: String, songIDs: [String]) async throws -> PlaylistMutationResult {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.PLAYLIST, method: "updatesongs", version: 3,
            httpMethod: .post) {
                ("id", id)
                ("limit", 0)
                ("offset", -1)
                ("skip_duplicate", true)
                if !songIDs.isEmpty {
                    ("songs", songIDs.joined(separator: ","))
                }
            }
        let _: EmptyData = try await apiClient.request(api)
        return PlaylistMutationResult(playlistID: id)
    }
}
