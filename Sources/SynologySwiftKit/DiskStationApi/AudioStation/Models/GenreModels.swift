//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Genre: Decodable, Sendable {
    public var name: String
}

public typealias GenreListResult = SynologyListResult<Genre>

extension SynologyListResult where T == Genre {
    public var genres: [Genre] { items }

    private enum ListCodingKeys: String, CodingKey {
        case offset
        case total
        case items = "genres"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ListCodingKeys.self)
        offset = try container.decode(Int.self, forKey: .offset)
        total = try container.decode(Int.self, forKey: .total)
        items = try container.decode([Genre].self, forKey: .items)
    }

}

