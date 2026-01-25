//

//
//
//  Created by Steven on 2024/7/7.
//

import Foundation

public struct TagEditorResult: Decodable {
    public var success: Bool
    public var readFailCount: Int
    public var lyrics: String?
    public var files: [TagEditorData]

    enum CodingKeys: String, CodingKey {
        case success
        case readFailCount = "read_fail_count"
        case lyrics
        case files
    }
}

public struct TagEditorRequest: Codable {
    public var audioInfos: [TagEditorData]

    public var lyrics: String
    public var coverType: String
    public var coverPath: String
    public var title: String
    public var artist: String
    public var album: String
    public var comment: String
    public var genre: String
    public var track: String
    public var disc: String
    public var year: String
    public var albumArtist: String
    public var composer: String
    public var codePage: String

    enum CodingKeys: String, CodingKey {
        case audioInfos
        case lyrics
        case coverType
        case coverPath
        case title
        case artist
        case album
        case comment
        case genre
        case track
        case disc
        case year
        case albumArtist = "album_artist"
        case composer
        case codePage
    }

    public init(
        audioInfos: [TagEditorData], lyrics: String, coverType: String, coverPath: String,
        title: String, artist: String, album: String, comment: String, genre: String, track: String,
        disc: String, year: String, albumArtist: String, composer: String, codePage: String
    ) {
        self.audioInfos = audioInfos
        self.lyrics = lyrics
        self.coverType = coverType
        self.coverPath = coverPath
        self.title = title
        self.artist = artist
        self.album = album
        self.comment = comment
        self.genre = genre
        self.track = track
        self.disc = disc
        self.year = year
        self.albumArtist = albumArtist
        self.composer = composer
        self.codePage = codePage
    }
}

public struct TagEditorData: Codable {
    public var album: String
    public var albumArtist: String
    public var artist: String
    public var comment: String
    public var composer: String
    public var disc: Int

    enum CodingKeys: String, CodingKey {
        case album
        case albumArtist = "album_artist"
        case artist
        case comment
        case composer
        case disc
        case genre
        case path
        case title
        case track
        case year
    }
    public var genre: String
    public var path: String
    public var title: String
    public var track: Int
    public var year: Int

    public init(
        album: String, albumArtist: String, artist: String, comment: String, composer: String,
        disc: Int, genre: String, path: String, title: String, track: Int, year: Int
    ) {
        self.album = album
        self.albumArtist = albumArtist
        self.artist = artist
        self.comment = comment
        self.composer = composer
        self.disc = disc
        self.genre = genre
        self.path = path
        self.title = title
        self.track = track
        self.year = year
    }
}
