//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public class AudioStationApi {
    public init() {
    }

    /**
     query song list
     */
    public func songList(limit: Int, offset: Int) async -> (total: Int, data: [Song]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "list", parameters: [
            "additional": "song_tag,song_audio,song_rating",
            "library": "all",
            "limit": limit,
            "offset": offset,
        ])

        do {
            let result = try await api.request(resultType: SongListResult.self)
            return (result.total, result.songs)
        } catch {
            Logger.error("AudioStationApi.songList error: \(error)")
        }

        return (0, [])
    }

    /**
     query playlist list
     */
    public func playlistList(limit: Int, offset: Int) async -> (total: Int, data: [Playlist]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "list", parameters: [
            "library": "all",
            "limit": limit,
            "offset": offset,
        ])

        do {
            let result = try await api.request(resultType: PlaylistListResult.self)
            return (result.total, result.playlists)
        } catch {
            Logger.error("AudioStationApi.playlist error: \(error)")
        }

        return (0, [])
    }

    /**
     query songs in  playlist
     */
    public func playlistGetInfo(id: String, limit: Int, offset: Int) async -> (total: Int, data: [Playlist]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "getinfo", version: 3, parameters: [
            "additional": "songs,songs_song_tag,songs_song_audio,songs_song_rating",
            "library": "all",
            "songs_limit": limit,
            "songs_offset": offset,
            "id": id,
        ])

        do {
            let result = try await api.request(resultType: PlaylistGetInfoResult.self)
            return (result.playlists.count, result.playlists)
        } catch {
            Logger.error("AudioStationApi.playlist error: \(error)")
        }

        return (0, [])
    }
}
