//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Genre: Decodable {
    public var name: String
}

public struct GenreListResult: Decodable {
    public var offset: Int

    public var total: Int

    public var genres: [Genre]
}
