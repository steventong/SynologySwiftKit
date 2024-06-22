//
//  File.swift
//
//
//  Created by Steven on 2024/6/22.
//

@testable import SynologySwiftKit
import XCTest

class PlaylistApiTest: XCTestCase {
    let audioStationApi = AudioStationApi()

    func testCreatePlaylist() async {
        do {
            UserDefaults.standard.setValue(SecretKey.host, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
            UserDefaults.standard.setValue(SecretKey.host_custom_domain, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
            UserDefaults.standard.setValue(SecretKey.sid, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)

            let result = try await audioStationApi.playlist_create(name: "TestPlaylist\(UUID().uuidString)", library: "personal", songs: nil)
            Logger.info("result: \(result)")
        } catch {
            Logger.error("error: \(error)")
        }
    }
}
