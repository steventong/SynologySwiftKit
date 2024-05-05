//
//  File.swift
//
//
//  Created by Steven on 2024/5/4.
//

import Foundation

public class QueryAllPlaylists {
    let audioStationApi = AudioStationApi()

    public init() {
    }

    public func queryAllPlaylists(queryPlaylistSongs: Bool = true, batchSize: Int = 5000, maxThreads: Int = 3,
                                  onPlaylistTaskUpdate: @escaping (_ playlists: [Playlist], _ total: Int) -> Void,
                                  onPlaylistSongTaskUpdate: @escaping (_ playlist: Playlist, _ songs: [Song], _ total: Int) -> Void,
                                  onTaskFinish: @escaping () -> Void) {
        Task {
            // query first batch
            let playlists_firstBatch = await audioStationApi.playlistList(limit: 1, offset: 0)

            let total = playlists_firstBatch.total
            if total == 0 {
                onTaskFinish()
                return
            }

            // 播放列表
            let playlists = await batchQueryPlaylistList(total: total, batchSize: batchSize, maxThreads: maxThreads, onTaskUpdate: onPlaylistTaskUpdate)

            // 播放列表内的歌曲列表
            if queryPlaylistSongs {
                await batchQueryPlaylistGetInfo(playlists: playlists, batchSize: batchSize, maxThreads: maxThreads, onTaskUpdate: onPlaylistSongTaskUpdate)
            }

            onTaskFinish()
        }
    }
}

extension QueryAllPlaylists {
    /**
     queryPlaylistList
     */
    private func queryPlaylistList(taskIndex: Int, batchSize: Int, total: Int, onTaskUpdate: @escaping (_ data: [Playlist], _ total: Int) -> Void) async -> [Playlist] {
        let playlistListResult = await audioStationApi.playlistList(limit: batchSize, offset: batchSize * taskIndex)
        onTaskUpdate(playlistListResult.data, total)
        return playlistListResult.data
    }

    /**
     batch queryPlaylistList
     */
    private func batchQueryPlaylistList(total: Int, batchSize: Int, maxThreads: Int, onTaskUpdate: @escaping (_ playlists: [Playlist], _ total: Int) -> Void) async -> [Playlist] {
        // task count
        let taskCount = total / batchSize + 1
        Logger.info("batchQueryPlaylistList task, total count = \(total), taskCount = \(taskCount)")

        let targetThreadsLimit = taskCount > maxThreads ? maxThreads : taskCount

        // execute task
        let playlists = await withTaskGroup(of: [Playlist].self, returning: [Playlist].self, body: { taskGroup in
            // 限制并发 https://stackoverflow.com/questions/70976323/how-to-constrain-concurrency-like-maxconcurrentoperationcount-with-swift-con
            for taskIndex in 0 ..< targetThreadsLimit {
                taskGroup.addTask {
                    await self.queryPlaylistList(taskIndex: taskIndex, batchSize: batchSize, total: total, onTaskUpdate: onTaskUpdate)
                }
            }

            var waitTaskIndex = targetThreadsLimit
            var playlists: [Playlist] = []

            while let playlist = await taskGroup.next(), playlist != nil {
                playlists.append(contentsOf: playlist)
                if waitTaskIndex < taskCount {
                    taskGroup.addTask { [waitTaskIndex] in
                        await self.queryPlaylistList(taskIndex: waitTaskIndex, batchSize: batchSize, total: total, onTaskUpdate: onTaskUpdate)
                    }
                    waitTaskIndex += 1
                }
            }

            return playlists
        })

        Logger.info("batchQueryPlaylistList task, all task done, total count = \(total), taskCount = \(taskCount)")
        return playlists
    }

    /**
     query music in playlist
     */
    private func queryPlaylistGetInfo(playlist: Playlist, onTaskUpdate: @escaping (_ playlist: Playlist, _ songs: [Song], _ total: Int) -> Void) async -> [Playlist] {
        let playlistGetInfoResult = await audioStationApi.playlistGetInfo(id: playlist.id, limit: 5000, offset: 0)
        onTaskUpdate(playlist, playlistGetInfoResult.data[0].songs, playlistGetInfoResult.data[0].songs.count)
        return playlistGetInfoResult.data
    }

    /**
     batch query music in playlist
     */
    private func batchQueryPlaylistGetInfo(playlists: [Playlist], batchSize: Int, maxThreads: Int, onTaskUpdate: @escaping (_ playlist: Playlist, _ songs: [Song], _ total: Int) -> Void) async {
        // task count
        let taskCount = playlists.count / batchSize + 1
        Logger.info("batchQueryPlaylistGetInfo task, total count = \(playlists.count), taskCount = \(taskCount)")

        let targetThreadsLimit = taskCount > maxThreads ? maxThreads : taskCount

        // execute task
        await withTaskGroup(of: Int.self, body: { taskGroup in
            // 限制并发 https://stackoverflow.com/questions/70976323/how-to-constrain-concurrency-like-maxconcurrentoperationcount-with-swift-con
            for taskIndex in 0 ..< targetThreadsLimit {
                taskGroup.addTask {
                    let playlist = await self.queryPlaylistGetInfo(playlist: playlists[taskIndex], onTaskUpdate: onTaskUpdate)
                    return playlist.count
                }
            }

            var waitTaskIndex = targetThreadsLimit
            while await taskGroup.next() != nil && waitTaskIndex < taskCount {
                taskGroup.addTask { [waitTaskIndex] in
                    let playlist = await self.queryPlaylistGetInfo(playlist: playlists[waitTaskIndex], onTaskUpdate: onTaskUpdate)
                    return playlist.count
                }
                waitTaskIndex += 1
            }
        })
    }
}
