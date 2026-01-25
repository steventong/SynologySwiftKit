//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Folder: Decodable {
    public var id: String

    public var path: String

    public var isPersonal: Bool?

    public var title: String

    public var type: String

    public var additional: SongAdditional?

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case isPersonal = "is_personal"
        case title
        case type
        case additional
    }
}

public struct FolderListResult: Decodable {
    public var id: String

    public var items: [Folder]

    public var offset: Int

    public var total: Int

    public var folderTotal: Int

    enum CodingKeys: String, CodingKey {
        case id
        case items
        case offset
        case total
        case folderTotal = "folder_total"
    }
}
