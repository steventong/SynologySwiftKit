//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Artist: Decodable, Sendable {
    public var name: String
}

public struct ArtistListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let artists: [Artist]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case artists
    }
}

