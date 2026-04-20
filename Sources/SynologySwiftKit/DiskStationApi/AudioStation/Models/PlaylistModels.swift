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

public struct PlaylistReference: Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct PlaylistDeletionResult: Sendable {
    public let requestedID: String
    public let failedItemIDs: [String]

    public init(requestedID: String, failedItemIDs: [String]) {
        self.requestedID = requestedID
        self.failedItemIDs = failedItemIDs
    }

    public var deleted: Bool {
        failedItemIDs.isEmpty
    }
}

public struct PlaylistMutationResult: Sendable {
    public let playlistID: String

    public init(playlistID: String) {
        self.playlistID = playlistID
    }
}

public enum SmartPlaylistMatchRule: String, Sendable {
    case all
    case any
}

public struct SmartPlaylistDefinition: Sendable {
    public let scope: SynologyLibraryScope
    public let matchRule: SmartPlaylistMatchRule
    public let serializedRules: String

    public init(scope: SynologyLibraryScope, matchRule: SmartPlaylistMatchRule, serializedRules: String) {
        self.scope = scope
        self.matchRule = matchRule
        self.serializedRules = serializedRules
    }
}

struct PlaylistListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let playlists: [Playlist]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case playlists
    }
}


struct PlaylistGetInfoResult: Decodable, Sendable {
    public var playlists: [Playlist]
}

struct PlaylistCreateResult: Decodable, Sendable {
    public var id: String
}

struct PlaylistRenameResult: Decodable, Sendable {
    public var id: String
}

struct PlaylistDeleteResult: Decodable, Sendable {
    public var errors: [String]
}
