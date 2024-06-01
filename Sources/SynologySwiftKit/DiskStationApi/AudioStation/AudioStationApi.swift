//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public class AudioStationApi {
    let songApi = SongApi()
    let streamApi = StreamApi()
    let coverApi = CoverApi()
    let playlistApi = PlaylistApi()
    let tagEditorApi = TagEditorApi()

    public init() {
    }

    /**
     query song list
     */
    public func songList(limit: Int, offset: Int) async throws -> (total: Int, data: [Song]) {
        return try await songApi.songList(limit: limit, offset: offset)
    }

    /**
     query song info
     */
    public func songGetInfo(id: String) async throws -> Song? {
        return try await songApi.songGetInfo(id: id)
    }

    /**
     songStreamUrl
     */
    public func songStreamUrl(id: String, position: Int = 0, quality: SongStreamQuality) throws -> URL? {
        return try streamApi.songStreamUrl(id: id, position: position, quality: quality)
    }

    /**
     音乐封面
     */
    public func songCoverURL(songId: String) throws -> URL? {
        return try coverApi.songCoverURL(songId: songId)
    }

    /**
     专辑封面
     /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&album_name=%E4%B8%83%E9%87%8C%E9%A6%99&album_artist_name=
     */
    public func albumCoverURL(albumName: String, albumArtistName: String) throws -> URL? {
        return try coverApi.albumCoverURL(albumName: albumName, albumArtistName: albumArtistName)
    }

    /**
     GET /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&artist_name=Backstreet%20Boys
     */
    public func artistCoverURL(artistName: String) throws -> URL? {
        return try coverApi.artistCoverURL(artistName: artistName)
    }

    /**
      /webapi/AudioStation/cover.cgi?api=SYNO.AudioStation.Cover&method=getcover&version=3&library=all&composer_name=%E4%BA%94%E6%9C%88%E5%A4%A9
     */
    public func composerCoverURL(composerName: String) throws -> URL? {
        return try coverApi.composerCoverURL(composerName: composerName)
    }

    /**
     query playlist list
     */
    public func playlistList(limit: Int, offset: Int) async -> (total: Int, data: [Playlist]) {
        return await playlistApi.playlistList(limit: limit, offset: offset)
    }

    /**
     query playlist songs
     */
    public func playlistSongList(id: String, songsLimit: Int, songsOffset: Int) async -> (total: Int, data: [Song]) {
        return await playlistApi.playlistSongList(id: id, songsLimit: songsLimit, songsOffset: songsOffset)
    }

    /**
     创建播放列表
     */
    public func playlistCreate(name: String, shared: Bool, songs: String?) async -> String? {
        return await playlistApi.playlistCreate(name: name, shared: shared, songs: songs)
    }

    /**
     创建智能播放列表
     */
    public func playlistCreateSmart(name: String, shared: Bool, conj_rule: String, rules_json: String) async -> String? {
        return await playlistApi.playlistCreateSmart(name: name, shared: shared, conj_rule: conj_rule, rules_json: rules_json)
    }

    /**
     rename
     */
    public func playlistRename(id: String, newName: String) async -> String? {
        return await playlistApi.playlistRename(id: id, newName: newName)
    }

    /**
     delete
     */
    public func playlistDelete(id: String) async -> Bool {
        return await playlistApi.playlistDelete(id: id)
    }

    /**
     removemissing
     */
    public func playlistRemoveMissing(id: String) async -> Bool {
        return await playlistApi.playlistRemoveMissing(id: id)
    }

    /**
     updatesongs
     */
    public func playlistAddSongs(id: String, songs: [String]) async -> Bool {
        return await playlistApi.playlistAddSongs(id: id, songs: songs)
    }

    /**
     updatesongs
     */
    public func playlistRemoveSongs(id: String, songs: [String]) async -> Bool {
        return await playlistApi.playlistRemoveSongs(id: id, songs: songs)
    }

    /**
     tagEditorLoad
     */
    public func tagEditorLoad(path: String) async throws -> TagEditorResult? {
        return try await tagEditorApi.tagEditorLoad(path: path)
    }
}
