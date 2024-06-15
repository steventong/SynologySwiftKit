//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Composer: Decodable {
    public var name: String
}

public struct ComposerListResult: Decodable {
    public var offset: Int

    public var total: Int

    public var composers: [Composer]
}
