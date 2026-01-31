//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Composer: Decodable, Sendable {
    public var name: String
}

public typealias ComposerListResult = SynologyListResult<Composer>

extension SynologyListResult where T == Composer {
    public var composers: [Composer] { items }

    private enum ListCodingKeys: String, CodingKey {
        case offset
        case total
        case items = "composers"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ListCodingKeys.self)
        offset = try container.decode(Int.self, forKey: .offset)
        total = try container.decode(Int.self, forKey: .total)
        items = try container.decode([Composer].self, forKey: .items)
    }

}

