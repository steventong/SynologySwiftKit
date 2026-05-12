//
//  GenreModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - Genre

/// 流派数据模型
/// Genre data model
public struct Genre: Decodable, Sendable {
    /// 流派名称 / Genre name
    public var name: String
}

// MARK: - GenreListResult (Internal)

/// 流派列表接口响应（内部使用）
/// Genre list API response (internal use)
struct GenreListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let genres: [Genre]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case genres
    }
}
