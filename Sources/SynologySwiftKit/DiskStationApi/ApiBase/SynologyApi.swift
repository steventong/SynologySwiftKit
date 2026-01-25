//
//  SynologyApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - ApiDefinition

/// API 定义结构体
/// API definition structure
///
/// 使用示例 / Usage:
/// ```swift
/// let endpoint = ApiEndpoint(
///     api: SynologyApi.AudioStation.SONG,
///     method: "list",
///     parameters: ["limit": 100]
/// )
/// ```
public struct ApiDefinition: Equatable {
    /// API 名称
    public let name: String
    /// 是否需要认证
    public let requiresAuth: Bool
    /// 是否在 URL 中携带 sid
    public let requiresQuerySid: Bool

    /// 初始化 API 定义
    /// Initialize API definition
    public init(name: String, requiresAuth: Bool = true, requiresQuerySid: Bool = false) {
        self.name = name
        self.requiresAuth = requiresAuth
        self.requiresQuerySid = requiresQuerySid
    }
}

// MARK: - SynologyApi

/// Synology API 命名空间
/// Synology API namespace
///
/// 按功能模块组织 API 定义：
/// - `Core`: 核心 API（认证、加密等）
/// - `AudioStation`: 音频站 API
/// - `FileStation`: 文件站 API
public enum SynologyApi {
    // MARK: - Core APIs

    /// 核心 API
    public enum Core {
        /// API 信息查询
        public static let INFO = ApiDefinition(name: "SYNO.API.Info", requiresAuth: false)

        /// 认证 API
        public static let AUTH = ApiDefinition(name: "SYNO.API.Auth", requiresAuth: false)

        /// 加密 API
        public static let ENCRYPTION = ApiDefinition(name: "SYNO.API.Encryption", requiresAuth: false)

        /// DSM 信息
        public static let DSM_INFO = ApiDefinition(name: "SYNO.DSM.Info")
    }

    // MARK: - AudioStation APIs

    /// AudioStation API
    public enum AudioStation {
        /// 系统信息
        public static let INFO = ApiDefinition(name: "SYNO.AudioStation.Info")

        /// 歌曲
        public static let SONG = ApiDefinition(name: "SYNO.AudioStation.Song")

        /// 专辑
        public static let ALBUM = ApiDefinition(name: "SYNO.AudioStation.Album")

        /// 艺术家
        public static let ARTIST = ApiDefinition(name: "SYNO.AudioStation.Artist")

        /// 流派
        public static let GENRE = ApiDefinition(name: "SYNO.AudioStation.Genre")

        /// 作曲家
        public static let COMPOSER = ApiDefinition(name: "SYNO.AudioStation.Composer")

        /// 播放列表
        public static let PLAYLIST = ApiDefinition(name: "SYNO.AudioStation.Playlist")

        /// 浏览播放列表
        public static let browsePlaylist = ApiDefinition(name: "SYNO.AudioStation.Browse.Playlist")

        /// 文件夹
        public static let FOLDER = ApiDefinition(name: "SYNO.AudioStation.Folder")

        /// 封面（需要 sid 在 URL）
        public static let COVER = ApiDefinition(name: "SYNO.AudioStation.Cover", requiresQuerySid: true)

        /// 流媒体（需要 sid 在 URL）
        public static let STREAM = ApiDefinition(name: "SYNO.AudioStation.Stream", requiresQuerySid: true)

        /// 下载
        public static let DOWNLOAD = ApiDefinition(name: "SYNO.AudioStation.Download")

        /// 搜索
        public static let SEARCH = ApiDefinition(name: "SYNO.AudioStation.Search")

        /// 歌词
        public static let LYRICS = ApiDefinition(name: "SYNO.AudioStation.Lyrics")

        /// 歌词搜索
        public static let LYRICS_SEARCH = ApiDefinition(name: "SYNO.AudioStation.LyricsSearch")

        /// 收藏（Pin）
        public static let PIN = ApiDefinition(name: "SYNO.AudioStation.Pin")

        /// 标签
        public static let TAG = ApiDefinition(name: "SYNO.AudioStation.Tag")

        /// 标签编辑器 UI（非标准 API）
        public static let TAG_EDITOR_UI = ApiDefinition(name: "tagEditorUI")

        /// 网页播放器
        public static let WEB_PLAYER = ApiDefinition(name: "SYNO.AudioStation.WebPlayer")

        /// 电台
        public static let RADIO = ApiDefinition(name: "SYNO.AudioStation.Radio")

        /// 远程播放器
        public static let REMOTE_PLAYER = ApiDefinition(name: "SYNO.AudioStation.RemotePlayer")

        /// 远程播放器状态
        public static let REMOTE_PLAYER_STATUS = ApiDefinition(name: "SYNO.AudioStation.RemotePlayerStatus")

        /// 媒体服务器
        public static let MEDIA_SERVER = ApiDefinition(name: "SYNO.AudioStation.MediaServer")

        /// 代理
        public static let PROXY = ApiDefinition(name: "SYNO.AudioStation.Proxy")

        /// 语音助手
        public enum VoiceAssistant {
            public static let BROWSE = ApiDefinition(name: "SYNO.AudioStation.VoiceAssistant.Browse")
            public static let CHALLENGE = ApiDefinition(name: "SYNO.AudioStation.VoiceAssistant.Challenge")
            public static let INFO = ApiDefinition(name: "SYNO.AudioStation.VoiceAssistant.Info")
            public static let STREAM = ApiDefinition(name: "SYNO.AudioStation.VoiceAssistant.Stream")
        }
    }

    // MARK: - FileStation APIs

    /// FileStation API
    public enum FileStation {
        /// 删除
        public static let DELETE = ApiDefinition(name: "SYNO.FileStation.Delete")
    }
}
