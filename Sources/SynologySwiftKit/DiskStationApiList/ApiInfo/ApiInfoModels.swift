//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

struct ApiInfoNode: Decodable {
    let path: String
    let minVersion: Int
    let maxVersion: Int

    var requestFormat: String?
}
