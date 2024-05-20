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
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "list", version: 3, parameters: [
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
     High: /webapi/AudioStation/stream.cgi/0.wav?api=SYNO.AudioStation.Stream&version=2&method=transcode&format=wav&id=
     M: /webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=transcode&format=mp3&id=
     L: /webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=transcode&format=mp3&id=

     Original: /webapi/AudioStation/stream.cgi/0.mp3?api=SYNO.AudioStation.Stream&version=2&method=stream&id=
     */
    public func songStreamUrl(songId: String, position: Int = 0, quality: SongStreamQuality) throws -> URL? {
        let method = quality == .ORIGINAL ? "stream" : "transcode"
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw SynoDiskStationApiError.invalidSession
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_STREAM, method: method, version: 2, parameters: [
            "id": songId,
            "position": position,
            "format": quality.format ?? "",
            "bitrate": quality.bitrate ?? "",
            "_sid": sid,
        ])

        return api.requestUrl()
    }

    /**
     音乐封面
     /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getsongcover&version=1&library=all&id=music_6834&_sid=
     */
    public func songCoverURL(songId: String) throws -> URL? {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw SynoDiskStationApiError.invalidSession
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_COVER, method: "getsongcover", parameters: [
            "library": "all",
            "id": songId,
            "_sid": sid,
        ])

        return api.requestUrl()
    }

    /**
     专辑封面
     /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&album_name=%E4%B8%83%E9%87%8C%E9%A6%99&album_artist_name=
     */
    func albumCoverURL(albumName: String, artistName: String) throws -> URL? {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw SynoDiskStationApiError.invalidSession
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_COVER, method: "getcover", version: 3, parameters: [
            "library": "all",
            "album_name": albumName,
            "album_artist_name": artistName,
            "_sid": sid,
        ])

        return api.requestUrl()
    }

    /**
     GET /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&artist_name=Backstreet%20Boys
     */
    func artistCoverURL(artistName: String) throws -> URL? {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw SynoDiskStationApiError.invalidSession
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_COVER, method: "getcover", version: 3, parameters: [
            "library": "all",
            "artist_name": artistName,
            "_sid": sid,
        ])

        return api.requestUrl()
    }

    /**
      /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&composer_name=%E4%BA%94%E6%9C%88%E5%A4%A9
     */
    public func composerCoverURL(composerName: String) throws -> URL? {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw SynoDiskStationApiError.invalidSession
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_COVER, method: "getcover", version: 3, parameters: [
            "version": 3,
            "library": "all",
            "composer_name": composerName,
            "_sid": sid,
        ])

        return api.requestUrl()
    }

    /**
     query playlist list
     */
    public func playlistList(limit: Int, offset: Int) async -> (total: Int, data: [Playlist]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "list", version: 1, parameters: [
            "library": "all",
            "limit": limit,
            "offset": offset,
        ])

        do {
            let result = try await api.request(resultType: PlaylistListResult.self)
            return (result.total, result.playlists)
        } catch {
            Logger.error("AudioStationApi.playlistList error: \(error)")
        }

        return (0, [])
    }

    /**
     query playlist songs
     */
    public func playlistSongList(playlistId: String, limit: Int, offset: Int) async -> (total: Int, data: [Song]) {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "getinfo", version: 3, parameters: [
            "id": playlistId,
            "library": "all",
            "additional": "songs,songs_song_tag,songs_song_audio,songs_song_rating",
            "songs_limit": limit,
            "songs_offset": offset,
        ])

        do {
            let result = try await api.request(resultType: PlaylistGetInfoResult.self)
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
    public func playlistCreate(name: String, shared: Bool, songs: String?) async -> String? {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "create", version: 3, parameters: [
            "name": name,
            "library": shared ? "shared" : "personal",
            "songs": songs ?? "",
        ])

        do {
            let result = try await api.request(resultType: PlaylistCreateResult.self)
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
    public func playlistCreateSmart(name: String, shared: Bool, conj_rule: String, rules_json: String) async -> String? {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "createsmart", version: 2, parameters: [
            "name": name,
            "library": shared ? "shared" : "personal",
            "conj_rule": conj_rule,
            "rules_json": rules_json,
        ])

        do {
            let result = try await api.request(resultType: PlaylistCreateResult.self)
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
    public func playlistRename(id: String, newName: String) async -> String? {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "rename", version: 3, parameters: [
            "id": id,
            "new_name": newName,
        ])

        do {
            let result = try await api.request(resultType: PlaylistRenameResult.self)
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
    public func playlistDelete(id: String) async -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "delete", version: 3, parameters: [
            "id": id,
        ])

        do {
            let result = try await api.request(resultType: PlaylistDeleteResult.self)
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
    public func playlistRemoveMissing(id: String) async -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "removemissing", version: 3, parameters: [
            "id": id,
        ])

        do {
            let result = try await api.request(resultType: PlaylistRemoveMissingResult.self)
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
    public func playlistAddSongs(playlistId: String, songIds: [String]) async -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "updatesongs", version: 3, parameters: [
            "id": playlistId,
            "limit": 0,
            "offset": -1,
            "songs": songIds,
            "skip_duplicate": true,
        ])

        do {
            let result = try await api.request(resultType: PlaylistUpdateSongsResult.self)
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
    public func playlistRemoveSongs(playlistId: String, songIds: [String]) async -> Bool {
        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_PLAYLIST, method: "updatesongs", version: 3, parameters: [
            "id": playlistId,
            "limit": 0,
            "offset": -1,
            "songs": songIds,
            "skip_duplicate": true,
        ])

        do {
            let result = try await api.request(resultType: PlaylistUpdateSongsResult.self)
            return true
        } catch {
            Logger.error("AudioStationApi.playlistAddSongs error: \(error)")
        }

        return false
    }
}
