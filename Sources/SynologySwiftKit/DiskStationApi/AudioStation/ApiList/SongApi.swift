//
//  File.swift
//
//
//  Created by Steven on 2024/6/1.
//

import Foundation

class SongApi {
    /**
     query song list
     */
     func songList(limit: Int, offset: Int) async throws -> (total: Int, data: [Song]) {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw SynoDiskStationApiError.invalidSession
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "list", version: 3, parameters: [
            "additional": "song_tag,song_audio,song_rating",
            "library": "all",
            "limit": limit,
            "offset": offset,
        ])

        do {
            let result = try await api.requestForData(resultType: SongListResult.self)
            return (result.total, result.songs)
        } catch {
            Logger.error("AudioStationApi.songList error: \(error)")
        }

        return (0, [])
    }

    /**
     query song info

     /webapi/AudioStation/song.cgi?additional=song_rating&api=SYNO.AudioStation.Song&id=music_6910&method=getinfo&version=2
     {
         "success": true,
         "data": {
             "songs": [
                 {
                     "additional": {
                         "song_audio": {
                             "bitrate": 1536000,
                             "channel": 2,
                             "codec": "pcm_s16le",
                             "container": "wav",
                             "duration": 201,
                             "filesize": 38740388,
                             "frequency": 48000
                         },
                         "song_rating": {
                             "rating": 0
                         },
                         "song_tag": {
                             "album": "02 范特西",
                             "album_artist": "",
                             "artist": "",
                             "comment": "",
                             "composer": "",
                             "disc": 0,
                             "genre": "",
                             "track": 0,
                             "year": 0
                         }
                     },
                     "id": "music_6910",
                     "path": "/music/周杰伦/02 范特西/双截棍.wav",
                     "title": "双截棍",
                     "type": "file"
                 }
             ]
         }
     }
     */
     func songGetInfo(id: String) async throws -> Song? {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw SynoDiskStationApiError.invalidSession
        }

        let api = SynoDiskStationApi(api: .SYNO_AUDIO_STATION_SONG, method: "getinfo", version: 2, parameters: [
            "id": id,
            "additional": "song_tag,song_audio,song_rating",
        ])

        do {
            let result = try await api.requestForData(resultType: SongInfo.self)
            return result.songs.first
        } catch {
            Logger.error("AudioStationApi.songGetInfo error: \(error)")
        }

        return nil
    }


}
