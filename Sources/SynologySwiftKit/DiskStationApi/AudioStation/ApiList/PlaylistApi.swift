//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

extension AudioStationApi {
    /**
     query playlist list
     */
    public func playlistList(limit: Int, offset: Int) async throws -> (total: Int, data: [Playlist]) {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "list", version: 1, parameters: [
            "library": "all",
            "limit": limit,
            "offset": offset,
        ])

        let result = try await api.requestForData(resultType: PlaylistListResult.self)
        return (result.total, result.playlists)
    }

    /**
     query playlist songs
     */
    public func playlistSongList(id: String, songsLimit: Int, songsOffset: Int) async throws -> (total: Int, data: [Song]) {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "getinfo", version: 3, parameters: [
            "id": id,
            "library": "all",
            "additional": "songs,songs_song_tag,songs_song_audio,songs_song_rating",
            "songs_limit": songsLimit,
            "songs_offset": songsOffset,
        ])

        let result = try await api.requestForData(resultType: PlaylistGetInfoResult.self)
        if let playlist = result.playlists.first {
            return (playlist.songs_total, playlist.songs)
        }

        return (0, [])
    }

    /**
     创建播放列表

     api: SYNO.AudioStation.Playlist
     method: create
     name: 0505添加播放列表
     library: personal
     version: 3

     {"data":{"id":"playlist_personal_normal/0505添加播放列表"},"success":true}

     api: SYNO.AudioStation.Playlist
     method: create
     name: 0505群组
     library: shared
     version: 3

     {"data":{"id":"playlist_shared_normal/381"},"success":true}

     api: SYNO.AudioStation.Playlist
     method: create
     name: 1111
     library: personal
     version: 3
     songs: music_60241

     {"data":{"id":"playlist_personal_normal/1111"},"success":true}

     library :  "shared" , "personal" , all?
     */
    public func playlist_create(name: String, library: String, songs: String?) async throws -> String {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "create", version: 3, httpMethod: .post,
                                     parameters: ["name": name,
                                                  "library": library,
                                                  "songs": songs ?? ""])

        let result = try await api.requestForData(resultType: PlaylistCreateResult.self)
        return result.id
    }

    /**
     创建智能播放列表

     api: SYNO.AudioStation.Playlist
     version: 2
     library: shared
     conj_rule: or
     rules_json: [{"tag":1,"op":1,"tagval":"周杰伦","interval":0},{"tag":3,"op":1,"tagval":"张三","interval":0}]
     method: createsmart
     name: 智能列表

     {"data":{"id":"playlist_shared_normal/381"},"success":true}
     */
    public func playlistCreateSmart(name: String, shared: Bool, conj_rule: String, rules_json: String) async throws -> String? {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "createsmart", version: 2, parameters: [
            "name": name,
            "library": shared ? "shared" : "personal",
            "conj_rule": conj_rule,
            "rules_json": rules_json,
        ])

        let result = try await api.requestForData(resultType: PlaylistCreateResult.self)
        return result.id
    }

    /**

     api: SYNO.AudioStation.Playlist
     method: rename
     id: playlist_personal_normal/个人播放列表测试
     new_name: 个人播放列表测试del
     version: 3

     {"data":{"id":"playlist_personal_normal/个人播放列表测试del"},"success":true}

     */
    public func playlistRename(id: String, newName: String) async throws -> String? {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "rename", version: 3, parameters: [
            "id": id,
            "new_name": newName,
        ])

        let result = try await api.requestForData(resultType: PlaylistRenameResult.self)
        return result.id
    }

    /**

     api: SYNO.AudioStation.Playlist
     method: delete
     version: 3
     id: playlist_personal_normal/0505添加播放列表

     {"data":{"errors":[]},"success":true}

     */
    public func playlist_delete(id: String) async throws -> Bool {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "delete", version: 3, httpMethod: .post,
                                     parameters: [
                                         "id": id,
                                     ])

        let result = try await api.requestForData(resultType: PlaylistDeleteResult.self)
        return result.errors.isEmpty
    }

    /**
     api: SYNO.AudioStation.Playlist
     method: removemissing
     id: playlist_personal_normal/我喜爱的歌曲(由DSMusicApp标记)
     version: 3

     {"success":true}

     */
    public func playlistRemoveMissing(id: String) async throws -> Bool {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "removemissing", version: 3, parameters: [
            "id": id,
        ])

        try await api.request()
        return true
    }

    /**
     api: SYNO.AudioStation.Playlist
     method: updatesongs
     offset: -1
     limit: 0
     id: playlist_personal_normal/1111
     songs: music_60437,music_60241,music_60241,music_60437,music_62121,music_72815,music_61320,music_60692,music_60693,music_60695,music_60699,music_60701,music_60692,music_60693,music_60695,music_60699,music_60701,music_60692,music_60693,music_60695,music_60699,music_60701
     version: 3

     { "success": true }
     */
    public func playlistAddSongs(id: String, songs: [String]) async throws -> Bool {
        let api = try DiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "updatesongs", version: 3, parameters: [
            "id": id,
            "limit": 0,
            "offset": -1,
            "songs": songs,
            "skip_duplicate": true,
        ])

        try await api.request()
        return true
    }

    /**
     api: SYNO.AudioStation.Playlist
     method: updatesongs
     offset: 3
     limit: 5
     id: playlist_personal_normal/1111
     songs:
     version: 3

     api: SYNO.AudioStation.Playlist
     method: updatesongs
     offset: 3
     limit: 7
     id: playlist_personal_normal/1111
     songs: music_60695,music_60701,music_60693
     version: 3

     { "success": true }
     */
//    public func playlistRemoveSongs(id: String, songs: [String]) async throws -> Bool {
//        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "updatesongs", version: 3, parameters: [
//            "id": "id",
//            "limit": 0,
//            "offset": -1,
//            "songs": songs,
//            "skip_duplicate": true,
//        ])
//
//        do {
//            return try await api.request()
//        } catch {
//            Logger.error("AudioStationApi.PlaylistApi.playlistAddSongs error: \(error)")
//        }
//
//        return false
//    }
}
