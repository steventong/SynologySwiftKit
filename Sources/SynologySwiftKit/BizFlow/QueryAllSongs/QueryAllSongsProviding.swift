import Foundation

// MARK: - QueryAllSongsProviding

/// 批量查询歌曲流程提供者协议
/// Protocol defining the batch song query flow interface
///
/// 内部依赖注入接口，由 `QueryAllSongs` 实现，通过 `QueryAllSongsFlowClient` 对外暴露。
/// Internal dependency injection interface, implemented by `QueryAllSongs`, exposed via `QueryAllSongsFlowClient`.
protocol QueryAllSongsProviding {
    /// 查询歌曲总数（异步，单次结果）
    /// Query total songs count (async, single result)
    /// - Returns: 歌曲总数，失败时返回 -1 / Total count, -1 on failure
    func queryTotalSongsCount() async -> Int

    /// 批量查询所有歌曲
    /// Query all songs in batches
    /// - Parameters:
    ///   - batchSize: 每批次拉取数量 / Number of songs per batch
    ///   - concurrency: 并发任务数 / Number of concurrent tasks
    /// - Returns: AsyncStream 依次推送查询进度 / AsyncStream yielding query progress
    func queryAllSongs(batchSize: Int, concurrency: Int) -> AsyncStream<QueryAllSongsProgress>
}
