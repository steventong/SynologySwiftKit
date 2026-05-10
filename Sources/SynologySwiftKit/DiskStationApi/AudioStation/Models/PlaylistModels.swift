//

//
//
//  Created by Steven on 2024/5/4.
//

import Foundation

// MARK: - Playlist

/// 播放列表数据模型
/// Playlist data model
public struct Playlist: Decodable, Sendable {
    /// 播放列表 ID / Playlist ID
    public var id: String
    /// 所属媒体库（"shared" 或 "personal"）/ Library ("shared" or "personal")
    public var library: String
    /// 播放列表名称 / Playlist name
    public var name: String
    /// 分享状态 / Sharing status
    public var sharingStatus: String
    /// 播放列表类型（"normal" 或 "smart"）/ Playlist type ("normal" or "smart")
    public var type: String
    /// 额外信息（包含歌曲列表等）/ Additional info (contains song list, etc.)
    public var additional: PlaylistAdditional?

    /// 播放列表中的歌曲（来自 additional）/ Songs in playlist (from additional)
    public var songs: [Song] {
        additional?.songs ?? []
    }
    /// 歌曲起始偏移量 / Song start offset
    public var songsOffset: Int {
        additional?.songsOffset ?? 0
    }
    /// 歌曲总数 / Total song count
    public var songsTotal: Int {
        additional?.songsTotal ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case library
        case name
        case sharingStatus = "sharing_status"
        case type
        case additional
    }
}

// MARK: - PlaylistAdditional

/// 播放列表额外信息
/// Playlist additional info
public struct PlaylistAdditional: Decodable, Sendable {
    /// 歌曲列表 / Song list
    public var songs: [Song]
    /// 歌曲起始偏移量 / Song start offset
    public var songsOffset: Int
    /// 歌曲总数 / Total song count
    public var songsTotal: Int

    enum CodingKeys: String, CodingKey {
        case songs
        case songsOffset = "songs_offset"
        case songsTotal = "songs_total"
    }
}

// MARK: - PlaylistReference

/// 播放列表引用（创建/重命名操作返回的轻量结果）
/// Playlist reference (lightweight result returned by create/rename operations)
public struct PlaylistReference: Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

// MARK: - PlaylistDeletionResult

/// 播放列表删除结果
/// Playlist deletion result
public struct PlaylistDeletionResult: Sendable {
    /// 请求删除的播放列表 ID / Requested playlist ID
    public let requestedID: String
    /// 删除失败的子条目 ID 列表 / Failed item IDs
    public let failedItemIDs: [String]

    public init(requestedID: String, failedItemIDs: [String]) {
        self.requestedID = requestedID
        self.failedItemIDs = failedItemIDs
    }

    /// 是否完全删除成功 / Whether deletion was fully successful
    public var deleted: Bool {
        failedItemIDs.isEmpty
    }
}

// MARK: - PlaylistMutationResult

/// 播放列表修改操作结果（添加歌曲/移除歌曲等）
/// Playlist mutation result (add songs, remove songs, etc.)
public struct PlaylistMutationResult: Sendable {
    /// 被操作的播放列表 ID / Playlist ID that was modified
    public let playlistID: String

    public init(playlistID: String) {
        self.playlistID = playlistID
    }
}

// MARK: - SmartPlaylistMatchRule

/// 智能播放列表规则匹配方式
/// Smart playlist rule match mode
public enum SmartPlaylistMatchRule: String, Sendable {
    /// 所有规则均需满足（AND）/ All rules must match (AND)
    case all
    /// 任意规则满足即可（OR）/ Any rule matches (OR)
    case any
}

// MARK: - SmartPlaylistDefinition

/// 智能播放列表定义（创建时传入）
/// Smart playlist definition (passed when creating)
public struct SmartPlaylistDefinition: Sendable {
    /// 媒体库范围 / Library scope
    public let scope: SynologyLibraryScope
    /// 规则匹配方式（AND/OR）/ Rule match mode (AND/OR)
    public let matchRule: SmartPlaylistMatchRule
    /// 序列化后的规则 JSON 字符串 / Serialized rules JSON string
    public let serializedRules: String

    public init(scope: SynologyLibraryScope, matchRule: SmartPlaylistMatchRule, serializedRules: String) {
        self.scope = scope
        self.matchRule = matchRule
        self.serializedRules = serializedRules
    }
}

struct PlaylistListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let playlists: [Playlist]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case playlists
    }
}


struct PlaylistGetInfoResult: Decodable, Sendable {
    public var playlists: [Playlist]
}

struct PlaylistCreateResult: Decodable, Sendable {
    public var id: String
}

struct PlaylistRenameResult: Decodable, Sendable {
    public var id: String
}

struct PlaylistDeleteResult: Decodable, Sendable {
    public var errors: [String]
}
