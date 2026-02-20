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

    /**
     查询音乐的数量
     */
    public func queryTotalSongsCount() async -> Int {
        do {
            let songs = try await audioStationApi.songList(limit: 1, offset: 0, additional: nil)
            return songs.total
        } catch {
            return -1
        }
    }

    /**
     查询音乐列表
     */
    public func queryAllSongs(batchSize: Int = 500,
                              batchNum: Int = 3,
                              onTaskStart: @escaping (_ total: Int, _ tasks: Int) -> Void,
                              onTaskUpdate: @escaping (_ success: Bool, _ songs: [Song], _ currentCnt: Int, _ totalCnt: Int, _ error: String) -> Void,
                              onTaskEnd: @escaping (_ success: Bool, _ errorMsg: String) -> Void) {
        Task {
            let total = await queryTotalSongsCount()
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
            await withTaskGroup(of: Void.self, body: { taskGroup in
                // 限制并发 https://stackoverflow.com/questions/70976323/how-to-constrain-concurrency-like-maxconcurrentoperationcount-with-swift-con
                // task start
                for taskIndex in 0 ..< batchNum {
                    taskGroup.addTask {
                        let data = await self.querySongList(taskIndex: taskIndex, batchSize: batchSize, total: total)
                        onTaskUpdate(data.0, data.1, data.1.count, total, data.2)
                    }
                }

                // add more tasks
                var waitTask = batchNum
                while await taskGroup.next() != nil && waitTask < taskCount {
                    taskGroup.addTask { [waitTask] in
                        let data = await self.querySongList(taskIndex: waitTask, batchSize: batchSize, total: total)
                        onTaskUpdate(data.0, data.1, data.1.count, total, data.2)
                    }
                    waitTask += 1
                }
            })

            Logger.info("queryAllSongs task, all task done, total count = \(total), taskCount = \(taskCount)")
            onTaskEnd(true, "success")
        }
    }
}

extension QueryAllSongs {
    /**
     querySongList
     */
    private func querySongList(taskIndex: Int, batchSize: Int, total: Int) async -> (Bool, [Song], String) {
        Logger.debug("QueryAllSongs.querySongList task, begin querySongList, taskIndex = \(taskIndex), limit = \(batchSize), offset = \(batchSize * taskIndex)")

        do {
            let songListResult = try await audioStationApi.songList(limit: batchSize, offset: batchSize * taskIndex)

            Logger.debug("QueryAllSongs.querySongList task, finish handle querySongList result, taskIndex = \(taskIndex)")
            return (true, songListResult.data, "success")
        } catch {
            return (false, [], error.localizedDescription)
        }
    }
}
