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
            let playlists_firstBatch = try await audioStationApi.playlistList(limit: 1, offset: 0)

            let total = playlists_firstBatch.total
            if total == 0 {
                onTaskFinish()
                return
            }

            // 播放列表
            let playlists = await batchQueryPlaylistList(total: total, batchSize: batchSize, maxThreads: maxThreads, onTaskUpdate: onPlaylistTaskUpdate)

            // 播放列表内的歌曲列表
            if queryPlaylistSongs {
                await batchQueryPlaylistSongList(playlists: playlists, batchSize: batchSize, maxThreads: maxThreads, onTaskUpdate: onPlaylistSongTaskUpdate)
            }

            onTaskFinish()
        }
    }
}

extension QueryAllPlaylists {
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

            while let playlist = await taskGroup.next() {
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
     queryPlaylistList
     */
    private func queryPlaylistList(taskIndex: Int, batchSize: Int, total: Int, onTaskUpdate: @escaping (_ data: [Playlist], _ total: Int) -> Void) async -> [Playlist] {
        do {
            let playlistListResult = try await audioStationApi.playlistList(limit: batchSize, offset: batchSize * taskIndex)
            onTaskUpdate(playlistListResult.data, total)

            return playlistListResult.data
        } catch {
            return []
        }
    }

    /**
     batch query music in playlist
     */
    private func batchQueryPlaylistSongList(playlists: [Playlist], batchSize: Int, maxThreads: Int, onTaskUpdate: @escaping (_ playlist: Playlist, _ songs: [Song], _ total: Int) -> Void) async {
        guard !playlists.isEmpty else {
            return
        }

        // task count
        let taskCount = playlists.count / batchSize + 1
        Logger.info("batchQueryPlaylistGetInfo task, total count = \(playlists.count), taskCount = \(taskCount)")

        let targetThreadsLimit = taskCount > maxThreads ? maxThreads : taskCount

        // execute task
        await withTaskGroup(of: [Song].self, body: { taskGroup in
            // 限制并发 https://stackoverflow.com/questions/70976323/how-to-constrain-concurrency-like-maxconcurrentoperationcount-with-swift-con
            for taskIndex in 0 ..< targetThreadsLimit {
                taskGroup.addTask {
                    let songList = await self.queryPlaylistSongList(playlist: playlists[taskIndex], onTaskUpdate: onTaskUpdate)
                    return songList
                }
            }

            var waitTaskIndex = targetThreadsLimit
            while await taskGroup.next() != nil && waitTaskIndex < taskCount {
                taskGroup.addTask { [waitTaskIndex] in
                    let songList = await self.queryPlaylistSongList(playlist: playlists[waitTaskIndex], onTaskUpdate: onTaskUpdate)
                    return songList
                }
                waitTaskIndex += 1
            }
        })
    }

    /**
     query music in playlist
     */
    private func queryPlaylistSongList(playlist: Playlist, onTaskUpdate: @escaping (_ playlist: Playlist, _ songs: [Song], _ total: Int) -> Void) async -> [Song] {
        do {
            let songsResult = try await audioStationApi.playlistSongList(id: playlist.id, songsLimit: 5000, songsOffset: 0)
            onTaskUpdate(playlist, songsResult.data, songsResult.total)

            return songsResult.data
        } catch {
            return []
        }
    }
}
