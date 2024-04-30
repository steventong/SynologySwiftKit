//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public struct AuthResult: Decodable {
    public var did: String?

    public var is_portal_port: Bool

    public var sid: String

    public var synotoken: String?
}
