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
}

struct PlaylistAdditional: Decodable {
    var songs: [Song]
}

public struct PlaylistListResult: Decodable {
    var offset: Int
    var total: Int
    var playlists: [Playlist]
}

public struct PlaylistGetInfoResult: Decodable {
    var playlists: [Playlist]
}
