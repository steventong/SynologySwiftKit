//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Composer: Decodable, Sendable {
    public var name: String
}

public struct ComposerListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let composers: [Composer]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case composers
    }
}

