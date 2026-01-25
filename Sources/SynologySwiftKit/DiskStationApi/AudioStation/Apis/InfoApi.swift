//
//  InfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/22.
//

import Foundation
import OSLog

public final class InfoApi {
    private let apiClient: ApiClientProviding

    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /**
     Query AudioStation Info
     */
    public func query(
        cacheEnabled: Bool? = false, sid: String? = nil, did: String? = nil
    ) async throws -> AudioStationInfo {
        // Cache Check
        if cacheEnabled == true,
            isCacheValid(),
            let cachedInfo = getFromCache()
        {
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
    public func getFromCache() -> AudioStationInfo? {
        if let json = UserDefaults.standard.string(
            forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO.keyName),
            let data = json.data(using: .utf8)
        {
            let info = try? JSONDecoder().decode(AudioStationInfo.self, from: data)
            if let info {
                Logger.debug("SynologySwiftKit.InfoApi, query, from cache: \(info)")
            }
            return info
        }
        return nil
    }

    // MARK: - Private Methods

    private func queryFromDsm(sid: String? = nil, did: String? = nil) async throws
        -> AudioStationInfo
    {
        let result: AudioStationInfo = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.INFO,
                method: "getinfo",
                version: 6,
                httpMethod: .post,
                sidOnQuery: sid == nil,
                sidOnCookie: sid == nil
            ) {
                if let sid {
                    ("sid", sid)
                    ("did", did)
                }
            },
            resultType: AudioStationInfo.self
        )
        return result
    }

    private func saveToCache(info: AudioStationInfo) {
        if let encoded = try? JSONEncoder().encode(info),
            let json = String(data: encoded, encoding: .utf8)
        {
            UserDefaults.standard.setValue(
                json, forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO.keyName)
            UserDefaults.standard.set(
                Date(), forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName
            )
        }
    }

    private func isCacheValid() -> Bool {
        if let updateTime = UserDefaults.standard.object(
            forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName) as? Date
        {
            return Date().timeIntervalSince(updateTime) < 24 * 60 * 60
        }
        return false
    }
}
