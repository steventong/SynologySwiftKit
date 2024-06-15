//
//  File.swift
//  
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Genre: Decodable {
    var name: String
}

public struct GenreListResult: Decodable {
    
    var offset: Int
    
    var total: Int
    
    var genres: [Genre]
}
