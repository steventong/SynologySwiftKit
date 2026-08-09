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
/// let recentAlbums = try await audioStation.albums.list(
///     limit: 50,
///     offset: 0,
///     libraryScope: .shared,
///     includeFields: "avg_rating",
///     sort: SynologySortDescriptor(field: "time", direction: .descending)
/// )
/// ```
public final class AudioStationClient {

    // MARK: - Dependencies

    /// API 客户端（internal 以便 extension 访问）
    /// API client (internal for extension access)
    let apiClient: ApiEndpointClient

    // MARK: - API Modules

    /// 固定 API
    public let pins: PinApi

    /// 文件夹 API
    public let folders: FolderApi

    /// 专辑 API
    public let albums: AlbumApi

    /// 艺术家 API
    public let artists: ArtistApi

    /// 作曲家 API
    public let composers: ComposerApi

    /// 流派 API
    public let genres: GenreApi

    /// 歌曲 API
    public let songs: SongApi

    /// 播放列表 API
    public let playlists: PlaylistApi

    /// 歌词 API
    public let lyrics: LyricsApi

    /// 搜索 API
    public let search: SearchApi

    /// 封面 API
    public let covers: CoverApi

    /// 流媒体 API
    public let stream: StreamApi

    /// 信息 API
    public let info: InfoApi

    /// 标签编辑器 API
    public let tagEditor: TagEditorApi

    // MARK: - Initialization

    /// 初始化 AudioStation API
    /// Initialize AudioStation API
    /// - Parameter apiClient: API 客户端
    init(apiClient: ApiEndpointClient, keyValueStorage: KeyValueStorage = StorageService()) {
        self.apiClient = apiClient

        let info = InfoApi(apiClient: apiClient, keyValueStorage: keyValueStorage)
        pins = PinApi(apiClient: apiClient)
        folders = FolderApi(apiClient: apiClient)
        albums = AlbumApi(apiClient: apiClient)
        artists = ArtistApi(apiClient: apiClient)
        composers = ComposerApi(apiClient: apiClient)
        genres = GenreApi(apiClient: apiClient)
        songs = SongApi(apiClient: apiClient, urlBuilder: apiClient)
        playlists = PlaylistApi(apiClient: apiClient)
        lyrics = LyricsApi(apiClient: apiClient)
        search = SearchApi(apiClient: apiClient)
        covers = CoverApi(urlBuilder: apiClient)
        stream = StreamApi(
            urlBuilder: apiClient,
            transcodeCapabilityProvider: info
        )
        self.info = info
        tagEditor = TagEditorApi(apiClient: apiClient)
    }
}

// MARK: - Internal Helpers
