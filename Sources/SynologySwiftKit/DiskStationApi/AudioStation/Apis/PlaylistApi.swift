//
//  PlaylistApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

// MARK: - PlaylistApi

/// 播放列表 API 客户端
/// Playlist API client
///
/// 封装 `SYNO.AudioStation.Playlist` 接口，支持列表、创建、编辑、删除播放列表。
/// Wraps `SYNO.AudioStation.Playlist`; supports list, create, edit, and delete playlists.
public final class PlaylistApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) {
        self.apiClient = apiClient
    }

    /// 查询播放列表列表
    /// Query playlist list
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

    /// 查询播放列表内的歌曲
    /// Query songs inside a playlist
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

    /// 创建普通播放列表
    /// Create a regular playlist
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

    /// 创建智能播放列表
    /// Create a smart playlist
    /// - Throws: `SynologyError.api` 当操作失败时 / When operation fails
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

    /// 根据目录路径创建智能播放列表，包含子目录中的歌曲。
    /// Create a smart playlist matching the folder path, including songs in subfolders.
    /// - Parameter folderPath: 实际绝对目录路径（非虚拟根或文件夹 ID）；仅规范化尾部斜杠。
    ///   Actual absolute folder path (not a virtual root or folder ID); only trailing slashes are normalized.
    /// - Throws: `SynologyError.api` 当路径或目标媒体库非法时 / When the path or destination library is invalid.
    public func createFolderSmart(name: String, folderPath: String, libraryScope: SynologyLibraryScope = .personal) async throws -> PlaylistReference {
        guard libraryScope != .all else {
            throw SynologyError.api(code: -1, message: "Invalid playlist library scope")
        }

        let path = folderPath.dropLast(folderPath.reversed().prefix(while: { $0 == "/" }).count)
        let components = path.split(separator: "/", omittingEmptySubsequences: false).dropFirst()
        guard folderPath.hasPrefix("/"),
              !path.isEmpty,
              folderPath.rangeOfCharacter(from: .controlCharacters) == nil,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw SynologyError.api(code: -1, message: "Invalid folder path")
        }

        let rules = [FolderSmartRule(tagval: String(path) + "/")]
        let data = try JSONEncoder().encode(rules)
        return try await createSmart(
            name: name,
            definition: SmartPlaylistDefinition(
                scope: libraryScope,
                matchRule: .all,
                serializedRules: String(decoding: data, as: UTF8.self)
            )
        )
    }

    private struct FolderSmartRule: Encodable {
        let tag = 4
        let op = 4
        let tagval: String
        let interval = 0
    }

    /// 重命名播放列表
    /// Rename a playlist
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

    /// 删除播放列表
    /// Delete a playlist
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

    /// 移除播放列表中丢失的歌曲
    /// Remove missing songs from a playlist
    public func removeMissing(id: String) async throws -> PlaylistMutationResult {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.PLAYLIST, method: "removemissing", version: 3,
            httpMethod: .post) {
                ("id", id)
            }
        let _: EmptyData = try await apiClient.request(api)
        return PlaylistMutationResult(playlistID: id)
    }

    /// 添加歌曲到播放列表（自动跳过重复项）
    /// Add songs to a playlist (automatically skips duplicates)
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
