//
//  File.swift
//
//
//  Created by Steven on 2024/6/22.
//

import Foundation

extension AudioStationApi {
    /**
     queryAudioStationInfo
     */
    public func queryAudioStationInfo(cacheEnabled: Bool? = false) async throws -> AudioStationInfo {
        // 使用上次的记录, 从缓存获取，有效期一天
        if cacheEnabled == true,
           isAudioStationInfoCacheValid(),
           let cachedAudioStationInfo = queryAudioStationInfoFromCache() {
            return cachedAudioStationInfo
        }

        let audioStationInfo = try await queryAudioStationInfoFromDsm()
        Logger.debug("SynologySwiftKit.InfoApi, queryAudioStationInfo, query from api: \(audioStationInfo)")

        // save to userdefaults
        saveAudioStationInfoToUserDefaults(audioStationInfo: audioStationInfo)
        // result
        return audioStationInfo
    }

    /**
     queryAudioStationInfo
     */
    public func queryAudioStationInfoFromCache() -> AudioStationInfo? {
        // 使用上次的记录, 从缓存获取，有效期一天
        if let cachedAudioStationInfo = getAudioStationInfoFromUserDefaults() {
            Logger.debug("SynologySwiftKit.InfoApi, queryAudioStationInfo, query from userdefaults: \(cachedAudioStationInfo)")
            return cachedAudioStationInfo
        }

        return nil
    }
}

extension AudioStationApi {
    /**
     queryAudioStationInfoFromDsm
     */
    private func queryAudioStationInfoFromDsm() async throws -> AudioStationInfo {
        // 从接口查询
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_INFO, method: "getinfo", version: 4)

        let audioStationInfo = try await api.requestForData(resultType: AudioStationInfo.self)

        Logger.info("AudioStationApi.audioStationInfo: \(audioStationInfo)")
        return audioStationInfo
    }

    /**
     save to user defaults
     */
    private func saveAudioStationInfoToUserDefaults(audioStationInfo: AudioStationInfo) {
        if let encoded = try? JSONEncoder().encode(audioStationInfo),
           let audioStationInfoJson = String(data: encoded, encoding: .utf8) {
            UserDefaults.standard.setValue(audioStationInfoJson, forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO.keyName)
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName)
        }
    }

    /**
     get from user defaults
     */
    private func getAudioStationInfoFromUserDefaults() -> AudioStationInfo? {
        if let audioStationInfoJson = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO.keyName),
           let encoded = audioStationInfoJson.data(using: .utf8) {
            return try? JSONDecoder().decode(AudioStationInfo.self, from: encoded)
        }

        return nil
    }

    /**
     get update time
     */
    private func getAudioStationInfoSaveToUserDefaultsTime() -> Date? {
        if let date = UserDefaults.standard.object(forKey: UserDefaultsKeys.DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME.keyName) as? Date {
            return date
        }

        return nil
    }

    /**
     check time is expired or not (1 day valid)
     */
    private func isAudioStationInfoCacheValid() -> Bool {
        if let updateTime = getAudioStationInfoSaveToUserDefaultsTime() {
            let timeInterval = Date().timeIntervalSince(updateTime)
            // one day cache valid duration
            return timeInterval < 24 * 60 * 60
        }

        return false
    }
}
