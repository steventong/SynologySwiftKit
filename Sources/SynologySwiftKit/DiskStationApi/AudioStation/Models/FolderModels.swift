//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Folder: Decodable {
    public var id: String

    public var path: String

    public var is_personal: Bool?

    public var title: String

    public var type: String

    public var additional: SongAdditional?
}

public struct FolderListResult: Decodable {
    public var id: String

    public var items: [Folder]

    public var offset: Int

    public var total: Int

    public var folder_total: Int
}
