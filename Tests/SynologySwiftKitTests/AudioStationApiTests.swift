//
//  File.swift
//  
//
//  Created by Steven on 2024/5/19.
//


@testable import SynologySwiftKit
import XCTest

final class AudioStationApiTests: XCTestCase {
    
    let audioStationApi = AudioStationApi()
    
    func testGetApiInfo() async throws {
        
        UserDefaults.standard.setValue("https://example.com:5000", forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        UserDefaults.standard.setValue(1, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
        
        let lowQualityURL = audioStationApi.songStreamUrl(musicId: "music_1234", quality: .LOW)
        let mediumQualityURL = audioStationApi.songStreamUrl(musicId: "music_1234", quality: .MEDIUM)
        let highQualityURL = audioStationApi.songStreamUrl(musicId: "music_1234", quality: .HIGH)
        print("lowQualityURL: \(lowQualityURL)")
        print("mediumQualityURL: \(mediumQualityURL)")
        print("highQualityURL: \(highQualityURL)")
    }
}
