//
//  File.swift
//  
//
//  Created by Steven on 2024/6/15.
//

import Foundation

public struct Artist: Decodable {
    var name: String

}


public struct ArtistListResult: Decodable {
    
    var offset: Int
    
    var total: Int
    
    var artists: [Artist]
}
