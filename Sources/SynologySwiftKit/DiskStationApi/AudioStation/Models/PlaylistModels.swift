//

//
//
//  Created by Steven on 2024/5/4.
//

import Foundation

public struct Playlist: Decodable {
    public var id: String
    public var library: String
    public var name: String
    public var sharingStatus: String
    public var type: String

    public var additional: PlaylistAdditional?

    public var songs: [Song] {
        additional?.songs ?? []
    }

    public var songsOffset: Int {
        additional?.songsOffset ?? 0
    }

    public var songsTotal: Int {
        additional?.songsTotal ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case library
        case name
        case sharingStatus = "sharing_status"
        case type
        case additional
    }
}

public struct PlaylistAdditional: Decodable {
    public var songs: [Song]

    public var songsOffset: Int
    public var songsTotal: Int

    enum CodingKeys: String, CodingKey {
        case songs
        case songsOffset = "songs_offset"
        case songsTotal = "songs_total"
    }
}

public struct PlaylistListResult: Decodable {
    public var offset: Int
    public var total: Int
    public var playlists: [Playlist]
}

public struct PlaylistGetInfoResult: Decodable {
    public var playlists: [Playlist]
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
