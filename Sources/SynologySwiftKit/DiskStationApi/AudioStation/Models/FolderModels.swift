//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Folder: Decodable {
    var id: String

    var path: String

    var is_personal: Bool?

    var title: String

    var type: String

    var additional: SongAdditional?
}

public struct FolderListResult: Decodable {
    var id: String

    var items: [Folder]

    var offset: Int

    var total: Int

    var folder_total: Int
}
