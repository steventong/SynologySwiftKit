//
//  AudioStationClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - AudioStation API Client

/// AudioStation API 客户端（依赖注入）
/// AudioStation API Client (dependency injection)
///
/// 使用示例 / Usage:
/// ```swift
/// let audioStation = AudioStationClient(apiClient: client.apiClient)
/// let page = try await audioStation.pins.list()
/// let items = page.items
/// let songs = try await audioStation.songs.list(limit: 100, offset: 0)
/// ```
public final class AudioStationClient {

    // MARK: - Dependencies

    /// API 客户端（internal 以便 extension 访问）
    /// API client (internal for extension access)
    let apiClient: ApiClientProviding
    private let keyValueStorage: KeyValueStorage

    // MARK: - API Modules

    /// 固定 API
    public lazy var pins: PinApi = PinApi(apiClient: apiClient)

    /// 文件夹 API
    public lazy var folders = FolderApi(apiClient: apiClient)

    /// 专辑 API
    public lazy var albums = AlbumApi(apiClient: apiClient)

    /// 艺术家 API
    public lazy var artists = ArtistApi(apiClient: apiClient)

    /// 作曲家 API
    public lazy var composers = ComposerApi(apiClient: apiClient)

    /// 流派 API
    public lazy var genres = GenreApi(apiClient: apiClient)

    /// 歌曲 API
    public lazy var songs = SongApi(apiClient: apiClient)

    /// 播放列表 API
    public lazy var playlists = PlaylistApi(apiClient: apiClient)

    /// 歌词 API
    public lazy var lyricsCatalog = LyricsApi(apiClient: apiClient)

    /// 搜索 API
    public lazy var search = SearchApi(apiClient: apiClient)

    /// 封面 API
    public lazy var covers = CoverApi(apiClient: apiClient)

    /// 流媒体 API
    public lazy var playback = StreamApi(apiClient: apiClient)

    /// 信息 API
    public lazy var info = InfoApi(apiClient: apiClient, keyValueStorage: keyValueStorage)

    /// 标签编辑器 API
    public lazy var tagEditor = TagEditorApi(apiClient: apiClient)

    // MARK: - Initialization

    /// 初始化 AudioStation API
    /// Initialize AudioStation API
    /// - Parameter apiClient: API 客户端
    init(apiClient: ApiClientProviding, keyValueStorage: KeyValueStorage = UserDefaultsStorage()) {
        self.apiClient = apiClient
        self.keyValueStorage = keyValueStorage
    }
}

// MARK: - Internal Helpers
