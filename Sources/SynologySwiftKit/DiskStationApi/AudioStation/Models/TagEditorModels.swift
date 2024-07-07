//
//  File.swift
//
//
//  Created by Steven on 2024/7/7.
//

import Foundation

public struct TagEditorResult: Decodable {
    public var success: Bool
    public var read_fail_count: Int
    public var lyrics: String?
    public var files: [TagEditorData]
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
    public var album_artist: String
    public var composer: String
    public var codePage: String
}

public struct TagEditorData: Codable {
    public var album: String
    public var album_artist: String
    public var artist: String
    public var comment: String
    public var composer: String
    public var disc: Int
    public var genre: String
    public var path: String
    public var title: String
    public var track: Int
    public var year: Int
}
