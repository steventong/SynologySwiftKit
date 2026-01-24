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
///     api: SynologyApi.AudioStation.song,
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
    public init(
        name: String,
        requiresAuth: Bool = true,
        requiresQuerySid: Bool = false
    ) {
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
        public static let info = ApiDefinition(
            name: "SYNO.API.Info",
            requiresAuth: false
        )

        /// 认证 API
        public static let auth = ApiDefinition(
            name: "SYNO.API.Auth",
            requiresAuth: false
        )

        /// 加密 API
        public static let encryption = ApiDefinition(
            name: "SYNO.API.Encryption",
            requiresAuth: false
        )

        /// DSM 信息
        public static let dsmInfo = ApiDefinition(name: "SYNO.DSM.Info")
    }

    // MARK: - AudioStation APIs

    /// AudioStation API
    public enum AudioStation {
        /// 音频站信息
        public static let info = ApiDefinition(name: "SYNO.AudioStation.Info")

        /// 歌曲
        public static let song = ApiDefinition(name: "SYNO.AudioStation.Song")

        /// 专辑
        public static let album = ApiDefinition(name: "SYNO.AudioStation.Album")

        /// 艺术家
        public static let artist = ApiDefinition(name: "SYNO.AudioStation.Artist")

        /// 流派
        public static let genre = ApiDefinition(name: "SYNO.AudioStation.Genre")

        /// 作曲家
        public static let composer = ApiDefinition(name: "SYNO.AudioStation.Composer")

        /// 播放列表
        public static let playlist = ApiDefinition(name: "SYNO.AudioStation.Playlist")

        /// 浏览播放列表
        public static let browsePlaylist = ApiDefinition(name: "SYNO.AudioStation.Browse.Playlist")

        /// 文件夹
        public static let folder = ApiDefinition(name: "SYNO.AudioStation.Folder")

        /// 封面（需要 sid 在 URL）
        public static let cover = ApiDefinition(
            name: "SYNO.AudioStation.Cover",
            requiresQuerySid: true
        )

        /// 流媒体（需要 sid 在 URL）
        public static let stream = ApiDefinition(
            name: "SYNO.AudioStation.Stream",
            requiresQuerySid: true
        )

        /// 下载
        public static let download = ApiDefinition(name: "SYNO.AudioStation.Download")

        /// 搜索
        public static let search = ApiDefinition(name: "SYNO.AudioStation.Search")

        /// 歌词
        public static let lyrics = ApiDefinition(name: "SYNO.AudioStation.Lyrics")

        /// 歌词搜索
        public static let lyricsSearch = ApiDefinition(name: "SYNO.AudioStation.LyricsSearch")

        /// 收藏（Pin）
        public static let pin = ApiDefinition(name: "SYNO.AudioStation.Pin")

        /// 标签
        public static let tag = ApiDefinition(name: "SYNO.AudioStation.Tag")

        /// 标签编辑器 UI（非标准 API）
        public static let tagEditorUI = ApiDefinition(name: "tagEditorUI")

        /// 网页播放器
        public static let webPlayer = ApiDefinition(name: "SYNO.AudioStation.WebPlayer")

        /// 电台
        public static let radio = ApiDefinition(name: "SYNO.AudioStation.Radio")

        /// 远程播放器
        public static let remotePlayer = ApiDefinition(name: "SYNO.AudioStation.RemotePlayer")

        /// 远程播放器状态
        public static let remotePlayerStatus = ApiDefinition(
            name: "SYNO.AudioStation.RemotePlayerStatus")

        /// 媒体服务器
        public static let mediaServer = ApiDefinition(name: "SYNO.AudioStation.MediaServer")

        /// 代理
        public static let proxy = ApiDefinition(name: "SYNO.AudioStation.Proxy")

        /// 语音助手
        public enum VoiceAssistant {
            public static let browse = ApiDefinition(
                name: "SYNO.AudioStation.VoiceAssistant.Browse")
            public static let challenge = ApiDefinition(
                name: "SYNO.AudioStation.VoiceAssistant.Challenge")
            public static let info = ApiDefinition(name: "SYNO.AudioStation.VoiceAssistant.Info")
            public static let stream = ApiDefinition(
                name: "SYNO.AudioStation.VoiceAssistant.Stream")
        }
    }

    // MARK: - FileStation APIs

    /// FileStation API
    public enum FileStation {
        /// 删除
        public static let delete = ApiDefinition(name: "SYNO.FileStation.Delete")
    }
}
