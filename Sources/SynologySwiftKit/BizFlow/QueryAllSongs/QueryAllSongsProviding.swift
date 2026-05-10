import Foundation

protocol QueryAllSongsProviding {
    func queryTotalSongsCount() async -> Int
    func queryAllSongs(batchSize: Int, concurrency: Int) -> AsyncStream<QueryAllSongsProgress>
}
