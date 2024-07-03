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

        queryAllSongs.queryAllSongs(batchSize: 500, threads: 4,
                                    onTaskStart: { total, task in
                                        Logger.info("onTaskStart, total = \(total), task = \(task)")
                                    },
                                    onTaskUpdate: { _, songs, current, total, _ in
                                        Logger.info("onTaskUpdate, songs = \(songs.count), current = \(current), total = \(total)")
                                    },
                                    onTaskEnd: { _, _ in
                                        Logger.info("onTaskEnd")
                                    })
    }
}
