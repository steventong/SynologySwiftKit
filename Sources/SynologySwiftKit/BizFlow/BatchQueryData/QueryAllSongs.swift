//
//  File.swift
//
//
//  Created by Steven on 2024/5/4.
//

import Foundation

public class QueryAllSongs {
    let audioStationApi = AudioStationApi()

    public init() {
    }

    public func queryAllSongs(batchSize: Int = 5000, threads: Int = 3,
                              onTaskStart: @escaping (_ total: Int, _ tasks: Int) -> Void,
                              onTaskUpdate: @escaping (_ songs: [Song], _ currentCnt: Int, _ totalCnt: Int) -> Void,
                              onTaskEnd: @escaping (_ success: Bool, _ errorMsg: String) -> Void) {
        Task {
//            do {
            let total = await queryTotalSongCount()
            if total == -1 {
                onTaskEnd(true, NSLocalizedString("QUERY_SONGS_LIST_FAILED", comment: "QUERY_SONGS_LIST_FAILED"))
                return
            } else if total == 0 {
                onTaskEnd(true, NSLocalizedString("QUERY_SONGS_LIST_EMPTY", comment: "QUERY_SONGS_LIST_EMPTY"))
                return
            }

            // task count
            let taskCount = total / batchSize + 1
            Logger.debug("QueryAllSongs.queryAllSongs, total song list count = \(total), split task count = \(taskCount)")

            onTaskStart(total, taskCount)

            // execute task
            try await withThrowingTaskGroup(of: Void.self, body: { taskGroup in
                // 限制并发 https://stackoverflow.com/questions/70976323/how-to-constrain-concurrency-like-maxconcurrentoperationcount-with-swift-con
                // 首批任务添加
                for taskIndex in 0 ..< threads {
                    taskGroup.addTask {
                        let data = await self.querySongList(taskIndex: taskIndex, batchSize: batchSize, total: total)
                        onTaskUpdate(data, data.count, total)
                    }
                }

                // 后续任务追加
                var waitTaskIndex = threads
                while try await taskGroup.next() != nil && waitTaskIndex < taskCount {
                    taskGroup.addTask { [waitTaskIndex] in
                        let data = await self.querySongList(taskIndex: waitTaskIndex, batchSize: batchSize, total: total)
                        onTaskUpdate(data, data.count, total)
                    }
                    waitTaskIndex += 1
                }
            })

            Logger.info("queryAllSongs task, all task done, total count = \(total), taskCount = \(taskCount)")
            onTaskEnd(true, "success")
        }
    }
}

extension QueryAllSongs {
    /**
     获取歌曲总数
     */
    private func queryTotalSongCount() async -> Int {
        do {
            let songs = try await audioStationApi.songList(limit: 1, offset: 0)
            return songs.total
        } catch {
            return -1
        }
    }

    /**
     querySongList
     */
    private func querySongList(taskIndex: Int, batchSize: Int, total: Int) async -> [Song] {
        Logger.debug("QueryAllSongs.querySongList task, begin querySongList, taskIndex = \(taskIndex), limit = \(batchSize), offset = \(batchSize * taskIndex)")

        do {
            let songListResult = try await audioStationApi.songList(limit: batchSize, offset: batchSize * taskIndex)

            Logger.debug("QueryAllSongs.querySongList task, finish handle querySongList result, taskIndex = \(taskIndex)")
            return songListResult.data
        } catch {
            return []
        }
    }
}
