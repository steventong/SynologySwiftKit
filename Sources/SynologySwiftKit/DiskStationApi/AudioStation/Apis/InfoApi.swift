//
//  InfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/22.
//

import Foundation

public final class InfoApi {
    private let apiClient: ApiRequestSending
    private let keyValueStorage: KeyValueStorage

    init(apiClient: ApiRequestSending, keyValueStorage: KeyValueStorage = StorageService()) {
        self.apiClient = apiClient
        self.keyValueStorage = keyValueStorage
    }

    /// 查询 AudioStation 信息
    public func query(usesCache: Bool = false) async throws -> AudioStationInfo {
        // Cache Check
        if usesCache, isAudioStationInfoCacheValid(), let cachedInfo = cachedInfo() {
            return cachedInfo
        }

        // Network Request
        let info = try await queryFromDsm()
        Logger.debug("SynologySwiftKit.InfoApi, query, from api: \(info)")

        // Save Cache
        saveAudioStationInfoCache(info: info)
        return info
    }

    // MARK: - Private Methods

    func query(using session: SynologySession) async throws -> AudioStationInfo {
        let info = try await queryFromDsm(sid: session.sid, did: session.did)
        Logger.debug("SynologySwiftKit.InfoApi, query, from explicit session: \(info)")
        saveAudioStationInfoCache(info: info)
        return info
    }

    private func queryFromDsm(sid: String? = nil, did: String? = nil) async throws -> AudioStationInfo {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", version: 6, httpMethod: .post, sidOnQuery: sid == nil, sidOnCookie: sid == nil) {
            if let sid {
                ("sid", sid)
                ("did", did)
            }
        }
        let result: AudioStationInfo = try await apiClient.request(api)
        return result
    }

    func cachedInfo() -> AudioStationInfo? {
        if let info: AudioStationInfo = keyValueStorage.codable(forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO.keyName) {
            Logger.debug("SynologySwiftKit.InfoApi, query, from cache: \(info)")
            return info
        }
        return nil
    }

    private func saveAudioStationInfoCache(info: AudioStationInfo) {
        keyValueStorage.setCodable(info, forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO.keyName)
        keyValueStorage.setDate(Date(), forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName)
    }

    private func isAudioStationInfoCacheValid() -> Bool {
        if let updateTime = keyValueStorage.date(forKey: KeyValueStorageKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName) {
            return Date().timeIntervalSince(updateTime) < 24 * 60 * 60
        }
        return false
    }
}

protocol AudioTranscodeCapabilityProviding {
    func supportedTranscodeFormats() async throws -> Set<SongTranscodeFormat>
}

extension InfoApi: AudioTranscodeCapabilityProviding {
    func supportedTranscodeFormats() async throws -> Set<SongTranscodeFormat> {
        let info = try await query(usesCache: true)
        return Set(
            info.transcode_capability.compactMap {
                SongTranscodeFormat(rawValue: $0.lowercased())
            }
        )
    }
}
