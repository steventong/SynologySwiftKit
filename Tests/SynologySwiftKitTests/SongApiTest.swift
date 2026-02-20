//
//  File.swift
//  
//
//  Created by Steven on 2024/8/17.
//


@testable import SynologySwiftKit
import XCTest

class SongApiTest: XCTestCase {
    
    let audioStationApi = AudioStationApi()

    func testSongListUrl() throws {
        UserDefaults.standard.setValue("https://nas.example.com:5001", forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        UserDefaults.standard.setValue(1, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
        UserDefaults.standard.setValue("sample_sid", forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)

        let url = try audioStationApi.songListUrl(limit: 5000, offset: 0)
        debugPrint(url)
    }
}

