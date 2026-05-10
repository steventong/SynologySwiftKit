//
//  QueryAllSongs.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/5/4.
//

import Foundation

/// 批量查询所有歌曲（依赖注入）
/// Batch query all songs (dependency injection)
final class QueryAllSongs: QueryAllSongsProviding {
    private let songsApi: SongApi

    /// 初始化查询器
    /// Initialize query helper
    /// - Parameter apiClient: API 客户端
    init(apiClient: ApiRequestSending) {
        songsApi = SongApi(apiClient: apiClient)
    }

    // MARK: - Query Total Count

    /// 查询音乐总数
    /// Query total songs count
    /// - Returns: 歌曲总数，失败返回 -1
    func queryTotalSongsCount() async -> Int {
        do {
            let songs = try await songsApi.list(limit: 1, offset: 0, includeFields: nil)
            return songs.total
        } catch {
            return -1
        }
    }

    // MARK: - Query All Songs (AsyncStream)

    /// 查询所有歌曲（AsyncStream 版本）
    /// Query all songs with AsyncStream
    /// - Parameters:
    ///   - batchSize: 每批次查询数量
    ///   - concurrency: 并发任务数
    /// - Returns: AsyncStream 返回查询进度
    func queryAllSongs(batchSize: Int = 500, concurrency: Int = 3) -> AsyncStream<QueryAllSongsProgress> {
        AsyncStream { continuation in
            let task = Task {
                await self.performQueryAllSongs(
                    batchSize: batchSize,
                    concurrency: concurrency,
                    continuation: continuation
                )
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Private Support

private extension QueryAllSongs {
    /// 执行查询所有歌曲
    /// Perform query all songs
    func performQueryAllSongs(batchSize: Int, concurrency: Int, continuation: AsyncStream<QueryAllSongsProgress>.Continuation) async {
        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        // 获取总数
        let total = await queryTotalSongsCount()

        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        if total == -1 {
            continuation.yield(.failed(error: .fetchTotalFailed))
            continuation.finish()
            return
        } else if total == 0 {
            continuation.yield(.failed(error: .emptyList))
            continuation.finish()
            return
        }

        // 计算任务数
        let taskCount = (total + batchSize - 1) / batchSize
        Logger.debug("QueryAllSongs#performQueryAllSongs, total: \(total), taskCount: \(taskCount)")

        continuation.yield(.started(total: total, taskCount: taskCount))

        // 使用 TaskGroup 并发执行
        var completedBatches = 0
        var totalSongsQueried = 0

        await withTaskGroup(of: (Int, Bool, [Song], String).self) { taskGroup in
            // 启动初始并发任务
            for taskIndex in 0 ..< min(concurrency, taskCount) {
                taskGroup.addTask {
                    await self.querySongBatch(
                        batchIndex: taskIndex,
                        batchSize: batchSize,
                        total: total
                    )
                }
            }

            // 处理完成的任务并添加新任务
            var nextTaskIndex = concurrency

            for await result in taskGroup {
                guard !Task.isCancelled else {
                    taskGroup.cancelAll()
                    continuation.finish()
                    return
                }

                let (batchIndex, success, songs, errorMsg) = result
                completedBatches += 1

                if success {
                    totalSongsQueried += songs.count
                    continuation.yield(.batchCompleted(
                        songs: songs,
                        batchIndex: batchIndex,
                        batchCount: completedBatches,
                        total: total
                    ))
                } else {
                    continuation.yield(.batchFailed(batchIndex: batchIndex, error: errorMsg))
                }

                // 添加下一个任务
                if nextTaskIndex < taskCount {
                    let currentIndex = nextTaskIndex
                    taskGroup.addTask {
                        await self.querySongBatch(
                            batchIndex: currentIndex,
                            batchSize: batchSize,
                            total: total
                        )
                    }
                    nextTaskIndex += 1
                }
            }
        }

        Logger.info("QueryAllSongs#performQueryAllSongs, completed, total: \(totalSongsQueried)")
        continuation.yield(.completed(totalSongs: totalSongsQueried))
        continuation.finish()
    }

    /// 查询单批次歌曲
    /// Query single batch of songs
    func querySongBatch(batchIndex: Int, batchSize: Int, total: Int) async -> (Int, Bool, [Song], String) {
        if Task.isCancelled {
            return (batchIndex, false, [], CancellationError().localizedDescription)
        }

        let offset = batchSize * batchIndex

        Logger.debug("QueryAllSongs#querySongBatch, batchIndex: \(batchIndex), offset: \(offset), limit: \(batchSize)")

        do {
            let result = try await songsApi.list(
                limit: batchSize,
                offset: offset
            )

            Logger.debug("QueryAllSongs#querySongBatch, batchIndex: \(batchIndex), songs: \(result.items.count)")
            return (batchIndex, true, result.items, "success")
        } catch {
            Logger.error("QueryAllSongs#querySongBatch, batchIndex: \(batchIndex), error: \(error)")
            return (batchIndex, false, [], error.localizedDescription)
        }
    }
}
