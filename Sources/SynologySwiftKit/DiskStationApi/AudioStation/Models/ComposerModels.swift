//
//  ComposerModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - Composer

/// 作曲家数据模型
/// Composer data model
public struct Composer: Decodable, Sendable {
    /// 作曲家名称 / Composer name
    public var name: String
}

// MARK: - ComposerListResult (Internal)

/// 作曲家列表接口响应（内部使用）
/// Composer list API response (internal use)
struct ComposerListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let composers: [Composer]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case composers
    }
}
