//
//  InfoApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/22.
//

import Foundation

extension AudioStationApi {
    /**
     queryAudioStationInfo
     */
    public func queryAudioStationInfo(
        cacheEnabled: Bool? = false, sid: String? = nil, did: String? = nil
    ) async throws -> AudioStationInfo {
        // 使用上次的记录, 从缓存获取，有效期一天
        if cacheEnabled == true,
            isAudioStationInfoCacheValid(),
            let cachedAudioStationInfo = queryAudioStationInfoFromCache()
        {
            return cachedAudioStationInfo
        }

        let audioStationInfo = try await queryAudioStationInfoFromDsm(sid: sid, did: did)
        Logger.debug(
            "SynologySwiftKit.InfoApi, queryAudioStationInfo, query from api: \(audioStationInfo)")

        // save to userdefaults
        saveAudioStationInfoToUserDefaults(audioStationInfo: audioStationInfo)
        // result
        return audioStationInfo
    }

    /**
     queryAudioStationInfo
     */
    public func queryAudioStationInfoFromCache() -> AudioStationInfo? {
        if let cachedAudioStationInfo = getAudioStationInfoFromUserDefaults() {
            Logger.debug(
                "SynologySwiftKit.InfoApi, queryAudioStationInfo, query from userdefaults: \(cachedAudioStationInfo)"
            )
            return cachedAudioStationInfo
        }
        return nil
    }
}

extension AudioStationApi {
    /**
     queryAudioStationInfoFromDsm
     */
    private func queryAudioStationInfoFromDsm(sid: String? = nil, did: String? = nil) async throws
        -> AudioStationInfo
    {
        var parameters: [String: Any] = [:]
        if let sid {
            parameters["sid"] = sid
            parameters["did"] = did
        }

        let audioStationInfo: AudioStationInfo = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.AudioStation.info,
                method: "getinfo",
                version: 6,
                httpMethod: .post,
                parameters: parameters,
                sidOnQuery: sid == nil,
                sidOnCookie: sid == nil
            ),
            resultType: AudioStationInfo.self
        )

        Logger.info("AudioStationApi.audioStationInfo: \(audioStationInfo)")
        return audioStationInfo
    }

    private func saveAudioStationInfoToUserDefaults(audioStationInfo: AudioStationInfo) {
        if let encoded = try? JSONEncoder().encode(audioStationInfo),
            let audioStationInfoJson = String(data: encoded, encoding: .utf8)
        {
            UserDefaults.standard.setValue(
                audioStationInfoJson,
                forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO.keyName)
            UserDefaults.standard.set(
                Date(), forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName
            )
        }
    }

    private func getAudioStationInfoFromUserDefaults() -> AudioStationInfo? {
        if let audioStationInfoJson = UserDefaults.standard.string(
            forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO.keyName),
            let encoded = audioStationInfoJson.data(using: .utf8)
        {
            return try? JSONDecoder().decode(AudioStationInfo.self, from: encoded)
        }
        return nil
    }

    private func getAudioStationInfoSaveToUserDefaultsTime() -> Date? {
        UserDefaults.standard.object(
            forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName) as? Date
    }

    private func isAudioStationInfoCacheValid() -> Bool {
        if let updateTime = getAudioStationInfoSaveToUserDefaultsTime() {
            return Date().timeIntervalSince(updateTime) < 24 * 60 * 60
        }
        return false
    }
}
