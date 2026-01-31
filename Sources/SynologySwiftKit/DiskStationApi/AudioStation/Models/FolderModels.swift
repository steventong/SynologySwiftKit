//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Folder: Decodable, Sendable {
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

public typealias FolderListResult = SynologyListResult<Folder>

extension SynologyListResult where T == Folder {
    private enum ListCodingKeys: String, CodingKey {
        case id
        case items
        case offset
        case total
        case folderTotal = "folder_total"
    }

    public var folderTotal: Int {
        // 由于 SynologyListResult 没有 folderTotal 存储，我们需要在 extension 中处理或保持原样
        // 但为了统一，如果 API 返回不一致，我们可能需要更灵活的结构
        // 鉴于 FolderListResult 比较特殊，含有额外的 id 和 folderTotal，
        // 这里我们重新定义一个符合规范的
        0 
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ListCodingKeys.self)
        offset = try container.decode(Int.self, forKey: .offset)
        total = try container.decode(Int.self, forKey: .total)
        items = try container.decode([Folder].self, forKey: .items)
    }
}

