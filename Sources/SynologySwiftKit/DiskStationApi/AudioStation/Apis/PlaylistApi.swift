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

    /// 分页读取所有媒体库的播放列表。
    ///
    /// GET SYNO.AudioStation.Playlist/list，声明版本 1。
    ///
    /// 固定 library=all；不请求 additional。
    ///
    /// - Parameters:
    ///   - limit: 每页数量，必须指定。
    ///   - offset: 起始偏移，必须指定。
    /// - Returns: SynologyPage<Playlist>，来自 data.total/playlists。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
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

    /// 读取播放列表内的一页歌曲。
    ///
    /// POST SYNO.AudioStation.Playlist/getinfo，声明版本 3。
    ///
    /// 虽然请求 sharing_info，当前 PlaylistAdditional 只解码 songs/songs_offset/songs_total。
    ///
    /// - Parameters:
    ///   - id: 播放列表 ID。
    ///   - libraryScope: library，必须指定。
    ///   - includeFields: additional；默认 songs_song_tag,songs_song_audio,songs_song_rating,sharing_info。
    ///   - limit: songs_limit，歌曲子列表大小。
    ///   - offset: songs_offset，歌曲子列表偏移。
    ///   - sort: 当前实现不发送此参数，传值不会改变服务端顺序。
    /// - Returns: 第一份 playlist.additional 的 songs_total/songs；playlists 为空则返回空页。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
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

    /// 创建普通播放列表。
    ///
    /// POST SYNO.AudioStation.Playlist/create，声明版本 3。
    ///
    /// 不对 ID 内逗号进行额外转义；ID 应原样来自服务端。
    ///
    /// - Parameters:
    ///   - name: 列表名称，由服务端验证。
    ///   - libraryScope: 目标媒体库，应为 personal 或 shared；本方法未在本地拒绝 all。
    ///   - songIDs: 初始歌曲 ID，默认空数组；非空时以逗号拼接为 songs。
    /// - Returns: PlaylistReference，包含服务端返回的 id。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
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

    /// 创建按字符串规则筛选的智能播放列表。
    ///
    /// POST SYNO.AudioStation.Playlist/createsmart，声明版本 2。
    ///
    /// 规则使用数值 tag/op 和 tagval/interval，不支持日期或评分规则。规则值原样编码。
    ///
    /// - Parameters:
    ///   - name: 列表名称。
    ///   - definition: scope 只允许 personal/shared；matchRule 映射 and/or；rules 编码为 rules_json。
    /// - Returns: PlaylistReference，来自 data.id。
    /// - Throws: scope=all 时本地抛出 SynologyError.api(code: -1)；JSON 编码及请求错误向上传递。
    public func createSmart(name: String, definition: SmartPlaylistDefinition) async throws -> PlaylistReference {
        guard definition.scope != .all else {
            throw SynologyError.api(code: -1, message: "Invalid playlist library scope")
        }

        let data = try JSONEncoder().encode(definition.rules)
        let result: PlaylistCreateResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.PLAYLIST, method: "createsmart", version: 2,
                httpMethod: .post) {
                    ("name", name)
                    ("library", definition.scope.rawValue)
                    ("conj_rule", definition.matchRule.rawValue)
                    ("rules_json", String(decoding: data, as: UTF8.self))
                }
        )
        return PlaylistReference(id: result.id)
    }

    /// 修改播放列表名称。
    ///
    /// POST SYNO.AudioStation.Playlist/rename，声明版本 3。
    ///
    /// - Parameters:
    ///   - id: 播放列表 ID。
    ///   - name: 新名称，发送字段 new_name。
    /// - Returns: PlaylistReference，来自 data.id。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
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

    /// 删除播放列表并返回逐项失败信息。
    ///
    /// POST SYNO.AudioStation.Playlist/delete，声明版本 3。
    ///
    /// 顶层 success=true 不一定表示所有条目都删除成功。
    ///
    /// - Parameters:
    ///   - id: 播放列表 ID。
    /// - Returns: PlaylistDeletionResult；data.errors 映射 failedItemIDs，deleted 仅在其为空时为 true。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
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

    /// 移除播放列表中已失效的歌曲引用。
    ///
    /// POST SYNO.AudioStation.Playlist/removemissing，声明版本 3。
    ///
    /// 不删除 NAS 音频文件。
    ///
    /// - Parameters:
    ///   - id: 播放列表 ID。
    /// - Returns: PlaylistMutationResult，保存此次请求的 playlistID。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func removeMissing(id: String) async throws -> PlaylistMutationResult {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.PLAYLIST, method: "removemissing", version: 3,
            httpMethod: .post) {
                ("id", id)
            }
        let _: EmptyData = try await apiClient.request(api)
        return PlaylistMutationResult(playlistID: id)
    }

    /// 向播放列表末尾追加歌曲并跳过重复项。
    ///
    /// POST SYNO.AudioStation.Playlist/updatesongs，声明版本 3。
    ///
    /// 固定 offset=-1、limit=0、skip_duplicate=true；不是替换、重排或删除接口，不返回最终队列。
    ///
    /// - Parameters:
    ///   - id: 播放列表 ID。
    ///   - songIDs: 歌曲 ID 数组；以逗号连接，空数组时不发送 songs。
    /// - Returns: PlaylistMutationResult，保存此次请求的 playlistID。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
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
