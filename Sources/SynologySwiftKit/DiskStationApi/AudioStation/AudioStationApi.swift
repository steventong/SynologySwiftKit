//
//  AudioStationApi.swift
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
/// let audioStation = AudioStationApi(apiClient: client.apiClient)
/// let (total, items) = try await audioStation.pin.list()
/// let songs = try await audioStation.songList(limit: 100)
/// ```
public final class AudioStationApi {

    // MARK: - Dependencies

    /// API 客户端（internal 以便 extension 访问）
    /// API client (internal for extension access)
    let apiClient: ApiClientProviding

    // MARK: - API Modules

    /// 固定 API
    public lazy var pin: PinApi = PinApi(apiClient: apiClient)

    /// 文件夹 API
    public lazy var folder = FolderApi(apiClient: apiClient)

    /// 专辑 API
    public lazy var album = AlbumApi(apiClient: apiClient)

    /// 艺术家 API
    public lazy var artist = ArtistApi(apiClient: apiClient)

    /// 作曲家 API
    public lazy var composer = ComposerApi(apiClient: apiClient)

    /// 流派 API
    public lazy var genre = GenreApi(apiClient: apiClient)

    /// 歌曲 API
    public lazy var song = SongApi(apiClient: apiClient)

    /// 播放列表 API
    public lazy var playlist = PlaylistApi(apiClient: apiClient)

    /// 歌词 API
    public lazy var lyrics = LyricsApi(apiClient: apiClient)

    /// 搜索 API
    public lazy var search = SearchApi(apiClient: apiClient)

    /// 封面 API
    public lazy var cover = CoverApi(apiClient: apiClient)

    /// 流媒体 API
    public lazy var stream = StreamApi(apiClient: apiClient)

    /// 信息 API
    public lazy var info = InfoApi(apiClient: apiClient)

    /// 标签编辑器 API
    public lazy var tagEditor = TagEditorApi(apiClient: apiClient)

    // MARK: - Initialization

    /// 初始化 AudioStation API
    /// Initialize AudioStation API
    /// - Parameter apiClient: API 客户端
    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }
}

// MARK: - Internal Helpers

extension AudioStationApi {

    /// 获取当前会话 ID
    /// Get current session ID from UserDefaults
    /// - Throws: SynologyError.api(.invalidSession) if session not exist
    /// - Returns: Session ID string
    func getSessionId() throws -> String {
        guard
            let sid = UserDefaults.standard.string(
                forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        else {
            throw SynologyError.api(
                .invalidSession(code: 0, message: "invalid session, session not exist"))
        }
        return sid
    }
}
