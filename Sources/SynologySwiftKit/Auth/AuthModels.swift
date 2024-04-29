//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

extension Auth {

    public struct AuthResult: Decodable {
        
        var did: String?
        
        var is_portal_port: Bool
        
        var sid: String
        
        var synotoken: String?
    }
}
