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
