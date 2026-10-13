import Foundation

/// NAS 发现的播放设备；能力字段由 renderer 决定，可能缺省。
public struct RemotePlayer: Decodable, Sendable {
    public let id: String
    public let name: String
    public let type: String
    public let passwordProtected: Bool?
    public let supportsSeek: Bool?
    public let supportsVolume: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case passwordProtected = "password_protected"
        case supportsSeek = "support_seek"
        case supportsVolume = "support_set_volume"
    }

    /// 网页播放器与多 AirPlay 组合不是可单独投放的设备。
    public var isPhysicalDevice: Bool {
        id != "__SYNO_WEB_PLAYER__" && id != "__SYNO_Multiple_AirPlay__"
    }
}

struct RemotePlayerList: Decodable {
    let players: [RemotePlayer]
}

struct RemotePlayerQueue: Decodable {
    let total: Int
}
