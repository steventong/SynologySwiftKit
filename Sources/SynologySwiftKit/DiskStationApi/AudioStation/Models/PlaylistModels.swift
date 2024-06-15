//
//  File.swift
//
//
//  Created by Steven on 2024/5/4.
//

import Foundation

public struct Playlist: Decodable {
    public var id: String
    public var library: String
    public var name: String
    public var sharing_status: String
    public var type: String

    var additional: PlaylistAdditional?

    public var songs: [Song] {
        additional?.songs ?? []
    }

    public var songs_offset: Int {
        additional?.songs_offset ?? 0
    }

    public var songs_total: Int {
        additional?.songs_total ?? 0
    }
}

struct PlaylistAdditional: Decodable {
    var songs: [Song]

    var songs_offset: Int
    var songs_total: Int
}

public struct PlaylistListResult: Decodable {
    var offset: Int
    var total: Int
    var playlists: [Playlist]
}

public struct PlaylistGetInfoResult: Decodable {
    var playlists: [Playlist]
}

public struct PlaylistCreateResult: Decodable {
    public var id: String
}

public struct PlaylistRenameResult: Decodable {
    public var id: String
}

public struct PlaylistDeleteResult: Decodable {
    public var errors: [String]
}

public struct PlaylistRemoveMissingResult: Decodable {
    
}



public struct PlaylistUpdateSongsResult: Decodable {
    
}
