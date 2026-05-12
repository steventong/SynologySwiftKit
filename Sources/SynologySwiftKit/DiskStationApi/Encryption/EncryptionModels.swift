//
//  EncryptionModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/21.
//

import Foundation

// MARK: - ApiInfoEncryption

/// DSM 加密会话信息（由 `SYNO.API.Encryption` 接口返回）
/// DSM encryption session info (returned by `SYNO.API.Encryption`)
///
/// 用于在发起登录请求前获取加密参数，对密码进行 RSA 公钥加密。
/// Used to obtain encryption parameters before login, for RSA public-key password encryption.
public struct ApiInfoEncryption: Decodable, Sendable {
    /// 加密 Key（标识加密会话）
    /// Cipher key (identifies the encryption session)
    public let cipherkey: String

    /// 加密 Token（防重放攻击）
    /// Cipher token (anti-replay token)
    public let ciphertoken: String

    /// RSA 公钥（用于加密密码）
    /// RSA public key (for encrypting the password)
    public let publicKey: String

    /// 服务器时间戳（Unix 时间，可用于校验时间同步）
    /// Server timestamp (Unix time, can be used for time sync validation)
    public var serverTime: Int

    enum CodingKeys: String, CodingKey {
        case cipherkey
        case ciphertoken
        case publicKey = "public_key"
        case serverTime = "server_time"
    }
}
