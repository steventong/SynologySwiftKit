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
        let queryAllSongs = QueryAllSongs()

        try queryAllSongs.queryAllSongs(batchSize: 500, threads: 4, onTaskUpdate: { songs, total in
            Logger.info("onTaskUpdate, total = \(total), songs = \(songs.count)")
        }, onTaskFinish: {
            Logger.info("onTaskFinish")
        })
    }
}
