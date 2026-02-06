//
//  PingPongProviding.swift
//  SynologySwiftKit
//
//  Created by Steven on 06/02/2026.
//

import Foundation

public protocol PingPongProviding: Sendable {
    func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String]
    func pingpong(url: String) async -> Bool
}
