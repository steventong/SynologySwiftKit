//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Artist: Decodable, Sendable {
    public var name: String
}

public typealias ArtistListResult = SynologyListResult<Artist>

extension SynologyListResult where T == Artist {
    public var artists: [Artist] { items }

    private enum ListCodingKeys: String, CodingKey {
        case offset
        case total
        case items = "artists"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ListCodingKeys.self)
        offset = try container.decode(Int.self, forKey: .offset)
        total = try container.decode(Int.self, forKey: .total)
        items = try container.decode([Artist].self, forKey: .items)
    }

}

