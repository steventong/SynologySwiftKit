//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

class PlaylistApi {
    /**
     query playlist list
     */
    func playlistList(limit: Int, offset: Int) async -> (total: Int, data: [Playlist]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "list", version: 1, parameters: [
            "library": "all",
            "limit": limit,
            "offset": offset,
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistListResult.self)
            return (result.total, result.playlists)
        } catch {
            Logger.error("AudioStationApi.playlistList error: \(error)")
        }

        return (0, [])
    }

    /**
     query playlist songs
     */
    func playlistSongList(id: String, songsLimit: Int, songsOffset: Int) async -> (total: Int, data: [Song]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "getinfo", version: 3, parameters: [
            "id": id,
            "library": "all",
            "additional": "songs,songs_song_tag,songs_song_audio,songs_song_rating",
            "songs_limit": songsLimit,
            "songs_offset": songsOffset,
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistGetInfoResult.self)
            if let playlist = result.playlists.first {
                return (playlist.songs_total, playlist.songs)
            }

            return (0, [])
        } catch {
            Logger.error("AudioStationApi.playlistSongList error: \(error)")
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

     */
    func playlistCreate(name: String, shared: Bool, songs: String?) async -> String? {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "create", version: 3, parameters: [
            "name": name,
            "library": shared ? "shared" : "personal",
            "songs": songs ?? "",
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistCreateResult.self)
            return result.id
        } catch {
            Logger.error("AudioStationApi.playlistCreate error: \(error)")
        }

        return nil
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
    func playlistCreateSmart(name: String, shared: Bool, conj_rule: String, rules_json: String) async -> String? {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "createsmart", version: 2, parameters: [
            "name": name,
            "library": shared ? "shared" : "personal",
            "conj_rule": conj_rule,
            "rules_json": rules_json,
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistCreateResult.self)
            return result.id
        } catch {
            Logger.error("AudioStationApi.playlistCreateSmart error: \(error)")
        }

        return nil
    }

    /**

     api: SYNO.AudioStation.Playlist
     method: rename
     id: playlist_personal_normal/个人播放列表测试
     new_name: 个人播放列表测试del
     version: 3

     {"data":{"id":"playlist_personal_normal/个人播放列表测试del"},"success":true}

     */
    func playlistRename(id: String, newName: String) async -> String? {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "rename", version: 3, parameters: [
            "id": id,
            "new_name": newName,
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistRenameResult.self)
            return result.id
        } catch {
            Logger.error("AudioStationApi.playlistRename error: \(error)")
        }

        return nil
    }

    /**

     api: SYNO.AudioStation.Playlist
     method: delete
     version: 3
     id: playlist_personal_normal/0505添加播放列表

     {"data":{"errors":[]},"success":true}

     */
    func playlistDelete(id: String) async -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "delete", version: 3, parameters: [
            "id": id,
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistDeleteResult.self)
            return result.errors.isEmpty
        } catch {
            Logger.error("AudioStationApi.playlistDelete error: \(error)")
        }

        return false
    }

    /**
     api: SYNO.AudioStation.Playlist
     method: removemissing
     id: playlist_personal_normal/我喜爱的歌曲(由DSMusicApp标记)
     version: 3

     {"success":true}

     */
    func playlistRemoveMissing(id: String) async -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "removemissing", version: 3, parameters: [
            "id": id,
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistRemoveMissingResult.self)
            return true
        } catch {
            Logger.error("AudioStationApi.playlistDelete error: \(error)")
        }

        return false
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
    func playlistAddSongs(id: String, songs: [String]) async -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "updatesongs", version: 3, parameters: [
            "id": id,
            "limit": 0,
            "offset": -1,
            "songs": songs,
            "skip_duplicate": true,
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistUpdateSongsResult.self)
            return true
        } catch {
            Logger.error("AudioStationApi.playlistAddSongs error: \(error)")
        }

        return false
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
    func playlistRemoveSongs(id: String, songs: [String]) async -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "updatesongs", version: 3, parameters: [
            "id": "id",
            "limit": 0,
            "offset": -1,
            "songs": songs,
            "skip_duplicate": true,
        ])

        do {
            let result = try await api.requestForData(resultType: PlaylistUpdateSongsResult.self)
            return true
        } catch {
            Logger.error("AudioStationApi.playlistAddSongs error: \(error)")
        }

        return false
    }
}
