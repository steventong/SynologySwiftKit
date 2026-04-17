//

//
//
//  Created by Steven on 2024/6/21.
//

import Foundation

public struct ApiInfoEncryption: Decodable, Sendable {
    public let cipherkey: String
    public let ciphertoken: String
    public let publicKey: String
    public var serverTime: Int

    enum CodingKeys: String, CodingKey {
        case cipherkey
        case ciphertoken
        case publicKey = "public_key"
        case serverTime = "server_time"
    }
}
