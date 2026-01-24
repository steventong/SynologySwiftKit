//
//  AudioStationApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - AudioStation API Client

/// AudioStation API 客户端
/// 提供对群晖 AudioStation 各功能模块的统一访问入口
///
/// AudioStation API Client
/// Provides unified access to Synology AudioStation API modules
///
/// 使用示例 / Usage:
/// ```swift
/// let audioStation = AudioStationApi()
///
/// // 固定 API / Pin API
/// let (total, items) = try await audioStation.pin.list()
/// try await audioStation.pin.pinAlbum(album: "专辑名", albumArtist: "艺术家")
/// ```
public final class AudioStationApi {
    
    // MARK: - API Modules
    
    /// 固定 API
    /// Pin API for managing pinned items (albums, artists, folders, etc.)
    public let pin = PinApi()
    
    // MARK: - Initialization
    
    public init() {}
}

// MARK: - Internal Helpers

extension AudioStationApi {
    
    /// 获取当前会话 ID
    /// Get current session ID from UserDefaults
    /// - Throws: DiskStationApiError.invalidSession if session not exist
    /// - Returns: Session ID string
    func getSessionId() throws -> String {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw DiskStationApiError.invalidSession(0, "invalid session, session not exist")
        }
        return sid
    }
}
