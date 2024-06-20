//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public struct ApiInfoNode: Decodable {
    public let path: String
    public let minVersion: Int
    public let maxVersion: Int

    public var requestFormat: String?
}

public struct ApiInfoEncryption: Decodable {
    public let cipherkey: String
    public let ciphertoken: String
    public let public_key: String
    public var server_time: Int
}
