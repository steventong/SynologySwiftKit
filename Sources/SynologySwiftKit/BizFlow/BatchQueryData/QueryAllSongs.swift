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

    public func queryAllSongs(batchSize: Int = 5000, threads: Int = 3, onTaskUpdate: @escaping (_ songs: [Song], _ total: Int) -> Void, onTaskFinish: @escaping () -> Void) {
        Task {
            do {
                // query first batch
                let songs_firstBatch = try await audioStationApi.songList(limit: 1, offset: 0)

                let total = songs_firstBatch.total
                if total == 0 {
                    onTaskFinish()
                    return
                }

                // task count
                let taskCount = total / batchSize + 1
                Logger.info("queryAllSongs task, total count = \(total), taskCount = \(taskCount)")

                // execute task
                await withTaskGroup(of: Int.self, body: { taskGroup in
                    // 限制并发 https://stackoverflow.com/questions/70976323/how-to-constrain-concurrency-like-maxconcurrentoperationcount-with-swift-con
                    for taskIndex in 0 ..< threads {
                        taskGroup.addTask {
                            await self.querySongList(taskIndex: taskIndex, batchSize: batchSize, total: total, onTaskUpdate: onTaskUpdate)
                        }
                    }

                    var waitTaskIndex = threads
                    while await taskGroup.next() != nil && waitTaskIndex < taskCount {
                        taskGroup.addTask { [waitTaskIndex] in
                            await self.querySongList(taskIndex: waitTaskIndex, batchSize: batchSize, total: total, onTaskUpdate: onTaskUpdate)
                        }
                        waitTaskIndex += 1
                    }
                })

                Logger.info("queryAllSongs task, all task done, total count = \(total), taskCount = \(taskCount)")
                onTaskFinish()
            } catch {
                onTaskFinish()
            }
        }
    }
}

extension QueryAllSongs {
    /**
     querySongList
     */
    private func querySongList(taskIndex: Int, batchSize: Int, total: Int, onTaskUpdate: @escaping (_ data: [Song], _ total: Int) -> Void) async -> Int {
        do {
            Logger.debug("queryAllSongs task, begin querySongList, taskIndex = \(taskIndex), limit = \(batchSize), offset = \(batchSize * taskIndex)")
            let songListResult = try await audioStationApi.songList(limit: batchSize, offset: batchSize * taskIndex)

            Logger.debug("queryAllSongs task, begin handle querySongList result, taskIndex = \(taskIndex)")

            onTaskUpdate(songListResult.data, total)

            Logger.debug("queryAllSongs task, finish handle querySongList result, taskIndex = \(taskIndex)")

            return songListResult.data.count
        } catch {
            return 0
        }
    }
}
