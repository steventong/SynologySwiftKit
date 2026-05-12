//
//  ArtistModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - Artist

/// 艺术家数据模型
/// Artist data model
public struct Artist: Decodable, Sendable {
    /// 艺术家名称 / Artist name
    public var name: String
}

// MARK: - ArtistListResult (Internal)

/// 艺术家列表接口响应（内部使用）
/// Artist list API response (internal use)
struct ArtistListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let artists: [Artist]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case artists
    }
}
