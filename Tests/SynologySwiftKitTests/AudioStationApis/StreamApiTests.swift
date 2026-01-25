//

//  SynologySwiftKit
//
//  Created by Steven on 2025/2/8.
//

@testable import SynologySwiftKit
import XCTest

final class StreamApiTests: XCTestCase {
    let api = AudioStationApi()

    /**
     mp3格式，音质低。
     */
    func testSongStreamUrl() async throws {
        mockCache()
        
        let url = try api.songStreamUrl(id: "music_123", path: "/music/test/song.mp3", bitrate: 320000, frequency: 440000, quality: .HIGH)
        Logger.info(url.absoluteString)
    }

    /**
     设置mock属性
     */
    func mockCache() {
        UserDefaults.standard.set("https://test.synology.me", forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        UserDefaults.standard.setValue(1, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)

        UserDefaults.standard.set("sid12345", forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
    }
}
