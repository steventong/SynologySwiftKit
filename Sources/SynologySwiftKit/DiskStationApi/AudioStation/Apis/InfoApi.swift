//
//  InfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/22.
//

import Foundation

public final class InfoApi {
    private let apiClient: ApiClientProviding
    private let storage: KeyValueStorage

    public init(apiClient: ApiClientProviding, storage: KeyValueStorage = UserDefaultsStorage()) {
        self.apiClient = apiClient
        self.storage = storage
    }

    /**
     Query AudioStation Info
     */
    public func query(cacheEnabled: Bool? = false, sid: String? = nil, did: String? = nil) async throws -> AudioStationInfo {
        // Cache Check
        if cacheEnabled == true, isCacheValid(), let cachedInfo = getAudioStationInfo() {
            return cachedInfo
        }

        // Network Request
        let info = try await queryFromDsm(sid: sid, did: did)
        Logger.debug("SynologySwiftKit.InfoApi, query, from api: \(info)")

        // Save Cache
        saveToCache(info: info)
        return info
    }

    /**
     Query from Cache
     */
    public func getAudioStationInfo() -> AudioStationInfo? {
        if let json = storage.string(forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO.keyName),
           let data = json.data(using: .utf8) {
            let info = try? JSONDecoder().decode(AudioStationInfo.self, from: data)
            if let info {
                Logger.debug("SynologySwiftKit.InfoApi, query, from cache: \(info)")
            }
            return info
        }
        return nil
    }

    // MARK: - Private Methods

    private func queryFromDsm(sid: String? = nil, did: String? = nil) async throws -> AudioStationInfo {
        let api = ApiEndpoint(api: SynologyApi.AudioStation.INFO, method: "getinfo", version: 6, httpMethod: .post, sidOnQuery: sid == nil, sidOnCookie: sid == nil) {
            if let sid {
                ("sid", sid)
                ("did", did)
            }
        }
        let result: AudioStationInfo = try await apiClient.request(api, resultType: AudioStationInfo.self)
        return result
    }

    private func saveToCache(info: AudioStationInfo) {
        if let encoded = try? JSONEncoder().encode(info),
           let json = String(data: encoded, encoding: .utf8) {
            storage.set(json, forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO.keyName)
            storage.set(Date(), forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName
            )
        }
    }

    private func isCacheValid() -> Bool {
        if let updateTime = storage.object(forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName) as? Date {
            return Date().timeIntervalSince(updateTime) < 24 * 60 * 60
        }
        return false
    }
}
