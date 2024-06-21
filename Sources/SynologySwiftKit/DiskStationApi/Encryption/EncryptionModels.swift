//
//  File.swift
//  
//
//  Created by Steven on 2024/6/21.
//

import Foundation


public struct ApiInfoEncryption: Decodable {
    public let cipherkey: String
    public let ciphertoken: String
    public let public_key: String
    public var server_time: Int
}
