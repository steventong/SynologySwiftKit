//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public struct AuthResult: Decodable {
    public var did: String?

    public var isPortalPort: Bool

    public var sid: String

    public var synotoken: String?

    enum CodingKeys: String, CodingKey {
        case did
        case isPortalPort = "is_portal_port"
        case sid
        case synotoken
    }
}
