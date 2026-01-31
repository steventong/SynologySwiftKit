//

//
//
//  Created by Steven on 2024/5/4.
//

import Foundation

public struct Playlist: Decodable, Sendable {
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

public struct PlaylistAdditional: Decodable, Sendable {
    public var songs: [Song]

    public var songsOffset: Int
    public var songsTotal: Int

    enum CodingKeys: String, CodingKey {
        case songs
        case songsOffset = "songs_offset"
        case songsTotal = "songs_total"
    }
}

public typealias PlaylistListResult = SynologyListResult<Playlist>

extension SynologyListResult where T == Playlist {
    public var playlists: [Playlist] { items }

    private enum ListCodingKeys: String, CodingKey {
        case offset
        case total
        case items = "playlists"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ListCodingKeys.self)
        offset = try container.decode(Int.self, forKey: .offset)
        total = try container.decode(Int.self, forKey: .total)
        items = try container.decode([Playlist].self, forKey: .items)
    }

}


public struct PlaylistGetInfoResult: Decodable, Sendable {
    public var playlists: [Playlist]
}

public struct PlaylistCreateResult: Decodable, Sendable {
    public var id: String
}

public struct PlaylistRenameResult: Decodable, Sendable {
    public var id: String
}

public struct PlaylistDeleteResult: Decodable, Sendable {
    public var errors: [String]
}
