//

//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Genre: Decodable, Sendable {
    public var name: String
}

struct GenreListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let genres: [Genre]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case genres
    }
}
