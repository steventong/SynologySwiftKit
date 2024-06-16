//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Artist: Decodable {
    public var name: String
}

public struct ArtistListResult: Decodable {
    public var offset: Int

    public var total: Int

    public var artists: [Artist]
}
