//
//  PinApi+Models.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - Pin Item

/// 固定项目
/// Pinned item
public struct PinItem: Codable {
    /// 固定项 ID
    public let id: String?
    /// 固定项类型（album）
    public let type: String
    /// 显示名称
    public let name: String
    /// 筛选条件
    public let criteria: PinCriteria
}

/// 固定项筛选条件
/// Pin item criteria
public struct PinCriteria: Codable {
    /// 专辑名
    public var album: String?
    /// 专辑艺术家
    public var album_artist: String?
}

// MARK: - API Results

/// 固定列表结果
struct PinListResult: Codable {
    let items: [PinItem]
    let offset: Int
    let total: Int
}

/// 固定操作结果
struct PinOperationResult: Codable {
    let errors: [Int]
    let items: [PinItem]
}
