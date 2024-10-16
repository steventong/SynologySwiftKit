//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire

public enum DiskStationApiDefine: String {
    /**
     api info
     */
    case SYNO_API_INFO = "SYNO.API.Info"

    /**
     dsm
     */
    case SYNO_DSM_INFO = "SYNO.DSM.Info"

    /**
     Encryption
     */
    case SYNO_API_ENCRYPTION = "SYNO.API.Encryption"

    /**
     auth
     */
    case SYNO_API_AUTH = "SYNO.API.Auth"

    /**
     audio station - song
     */
    case SYNO_AUDIO_STATION_SONG = "SYNO.AudioStation.Song"
    /**
     audio station - playlist
     */
    case SYNO_AUDIO_STATION_PLAYLIST = "SYNO.AudioStation.Playlist"

    /**
     not standard api
     */
    case SYNO_AUDIO_STATION_TAG_EDITOR_UI = "tagEditorUI"

    /**
     audio station
     */
    case SYNO_AUDIO_STATION_INFO = "SYNO.AudioStation.Info"

    /**
     ==
     */
    case SYNO_AUDIO_STATION_ALBUM = "SYNO.AudioStation.Album"
    case SYNO_AUDIO_STATION_ARTIST = "SYNO.AudioStation.Artist"
    case SYNO_AUDIO_STATION_BROWSE_PLAYLIST = "SYNO.AudioStation.Browse.Playlist"
    case SYNO_AUDIO_STATION_COMPOSER = "SYNO.AudioStation.Composer"
    case SYNO_AUDIO_STATION_COVER = "SYNO.AudioStation.Cover"
    case SYNO_AUDIO_STATION_DOWNLOAD = "SYNO.AudioStation.Download"
    case SYNO_AUDIO_STATION_FOLDER = "SYNO.AudioStation.Folder"
    case SYNO_AUDIO_STATION_GENRE = "SYNO.AudioStation.Genre"
    case SYNO_AUDIO_STATION_LYRICS = "SYNO.AudioStation.Lyrics"
    case SYNO_AUDIO_STATION_LYRICSSEARCH = "SYNO.AudioStation.LyricsSearch"
    case SYNO_AUDIO_STATION_MEDIASERVER = "SYNO.AudioStation.MediaServer"
    case SYNO_AUDIO_STATION_PIN = "SYNO.AudioStation.Pin"
    case SYNO_AUDIO_STATION_PROXY = "SYNO.AudioStation.Proxy"
    case SYNO_AUDIO_STATION_RADIO = "SYNO.AudioStation.Radio"
    case SYNO_AUDIO_STATION_REMOTEPLAYER = "SYNO.AudioStation.RemotePlayer"
    case SYNO_AUDIO_STATION_REMOTEPLAYERSTATUS = "SYNO.AudioStation.RemotePlayerStatus"
    case SYNO_AUDIO_STATION_SEARCH = "SYNO.AudioStation.Search"
    case SYNO_AUDIO_STATION_STREAM = "SYNO.AudioStation.Stream"
    case SYNO_AUDIO_STATION_TAG = "SYNO.AudioStation.Tag"
    case SYNO_AUDIO_STATION_VOICEASSISTANT_BROWSE = "SYNO.AudioStation.VoiceAssistant.Browse"
    case SYNO_AUDIO_STATION_VOICEASSISTANT_CHALLENGE = "SYNO.AudioStation.VoiceAssistant.Challenge"
    case SYNO_AUDIO_STATION_VOICEASSISTANT_INFO = "SYNO.AudioStation.VoiceAssistant.Info"
    case SYNO_AUDIO_STATION_VOICEASSISTANT_STREAM = "SYNO.AudioStation.VoiceAssistant.Stream"
    case SYNO_AUDIO_STATION_WEBPLAYER = "SYNO.AudioStation.WebPlayer"

    case SYNO_FILE_STATION_DELETE = "SYNO.FileStation.Delete"
    
    /**
     api name
     */
    var apiName: String {
        rawValue
    }

    /**
     api version
     */
    func apiInfo(apiName: String, method: String, version: Int, parameters: Parameters) throws -> (path: String, method: String, version: Int, parameters: Parameters) {
        // api query 直接返回
        if apiName == DiskStationApiDefine.SYNO_API_INFO.rawValue {
            return ("query.cgi", "query", 1, parameters: [:])
        }

        if let staticApiInfo = staticApiInfo(apiName: apiName) {
            return staticApiInfo
        }

        let apiInfo = try ApiInfoApi.shared.getApiInfoByApiName(apiName: apiName)

        // 适合的版本号
        let apiVersion = min(max(apiInfo.minVersion, version), apiInfo.maxVersion)

        // merge
        let mergedParameters = parameters.merging([
            "api": apiName,
            "version": apiVersion,
            "method": method,
        ]) { current, _ in current }

        return (apiInfo.path, method, apiVersion, mergedParameters)
    }

    /**
     assemble sid in cookie in request header
     */
    var requireAuthCookieHeader: Bool {
        switch self {
        case .SYNO_API_INFO:
            false
        case .SYNO_API_AUTH:
            false
        case .SYNO_API_ENCRYPTION:
            false
        default:
            true
        }
    }

    /**
     在URL地址上拼接 _sid 参数，一般是构造资源URL使用。
     */
    var requireAuthQueryParameter: Bool {
        switch self {
        case .SYNO_AUDIO_STATION_COVER:
            true
        case .SYNO_AUDIO_STATION_STREAM:
            true
        default:
            false
        }
    }

    /**
     某些特殊的API
     */
    func staticApiInfo(apiName: String) -> (path: String, method: String, version: Int, parameters: Parameters)? {
        switch apiName {
        case DiskStationApiDefine.SYNO_API_INFO.rawValue:
            return ("query.cgi", "query", 1, parameters: [:])
        default:
            return nil
        }
    }

    //    /**
    //     api Url
    //     */
    //    var apiPath: String {
    //        switch self {
    //        case .SYNO_API_INFO:
    //            return "/webapi/query.cgi"
    //        case .SYNO_API_ENCRYPTION:
    //            return "/webapi/encryption.cgi"
    //        case .SYNO_API_AUTH:
    //            return "/webapi/auth.cgi"
    //        case .SYNO_AUDIO_STATION_SONG:
    //            return "/webapi/AudioStation/song.cgi"
    //        case .SYNO_AUDIO_STATION_STREAM:
    //            return "/webapi/AudioStation/stream.cgi"
    //        case .SYNO_AUDIO_STATION_PLAYLIST:
    //            return "/webapi/AudioStation/playlist.cgi"
    //        case .SYNO_AUDIO_STATION_COVER:
    //            return "/webapi/AudioStation/cover.cgi"
    //        case .SYNO_AUDIO_STATION_ARTIST:
    //            return "/webapi/AudioStation/artist.cgi"
    //        case .SYNO_AUDIO_STATION_ALBUM:
    //            return "/webapi/AudioStation/album.cgi"
    //        case .SYNO_AUDIO_STATION_GENRE:
    //            return "/webapi/AudioStation/genre.cgi"
    //        case .SYNO_AUDIO_STATION_COMPOSER:
    //            return "/webapi/AudioStation/composer.cgi"
    //        case .SYNO_AUDIO_STATION_FOLDER:
    //            return "/webapi/AudioStation/folder.cgi"
    //        case .SYNO_AUDIO_STATION_LYRICS:
    //            return "/webapi/AudioStation/lyrics.cgi"
    //        case .SYNO_AUDIO_STATION_LYRICSSEARCH:
    //            return "/webapi/AudioStation/lyrics_search.cgi"
    //        case .SYNO_AUDIO_STATION_TAG_EDITOR_UI:
    //            return "/webman/3rdparty/AudioStation/tagEditorUI/tag_editor.cgi"
    //        default:
    //            return "/webapi/entry.cgi"
    //        }
    //    }
}
