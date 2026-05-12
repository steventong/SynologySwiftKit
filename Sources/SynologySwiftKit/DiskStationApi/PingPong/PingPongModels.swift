//
//  PingPongModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - PingPong.PingPongResult

extension PingPong {
    /// PingPong 接口响应模型（`/webman/pingpong.cgi`）
    /// PingPong API response model (`/webman/pingpong.cgi`)
    struct PingPongResult: Decodable {
        /// 是否可达（服务器正常响应则为 true）
        /// Whether the server is reachable (true if server responds normally)
        var success: Bool

        /// QuickConnect 扩展 ID（可选）
        /// QuickConnect extension ID (optional)
        var ezid: String?
    }
}
