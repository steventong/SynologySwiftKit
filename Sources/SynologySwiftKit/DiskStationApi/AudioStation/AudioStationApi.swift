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
    /// Pin API for managing pinned items
    public lazy var pin: PinApi = PinApi(apiClient: apiClient)

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
    /// - Throws: DiskStationApiError.invalidSession if session not exist
    /// - Returns: Session ID string
    func getSessionId() throws -> String {
        guard
            let sid = UserDefaults.standard.string(
                forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
        else {
            throw SynologyError.api(.invalidSession(code: 0, message: "invalid session, session not exist"))
        }
        return sid
    }
}
