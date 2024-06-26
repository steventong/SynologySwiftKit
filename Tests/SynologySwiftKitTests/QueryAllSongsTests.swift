//
//  File.swift
//
//
//  Created by Steven on 2024/5/4.
//
@testable import SynologySwiftKit
import XCTest

class QueryAllSongsTests: XCTestCase {
    func test() async throws {
        UserDefaults.standard.setValue(SecretKey.host, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        UserDefaults.standard.setValue(ConnectionType.custom_domain.rawValue, forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
//
        UserDefaults.standard.setValue(SecretKey.sid, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)

        let queryAllSongs = QueryAllSongs()

        queryAllSongs.queryAllSongs(batchSize: 500, threads: 4, onTaskUpdate: { songs, total in
            Logger.info("onTaskUpdate, total = \(total), songs = \(songs.count)")
        }, onTaskFinish: { _, _ in
            Logger.info("onTaskFinish")
        })
    }
}
