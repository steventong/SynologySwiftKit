//
//  File.swift
//
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Composer: Decodable {
    var name: String

}

public struct ComposerListResult: Decodable {
    var offset: Int
    
    var total: Int
    
    var composers: [Composer]
}
