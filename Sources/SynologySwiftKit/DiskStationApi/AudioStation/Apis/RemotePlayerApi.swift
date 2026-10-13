import Foundation

/// 由 NAS 向 DLNA / AirPlay renderer 播放，客户端只发送控制命令。
public final class RemotePlayerApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) { self.apiClient = apiClient }

    public func list() async throws -> [RemotePlayer] {
        let result: RemotePlayerList = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.REMOTE_PLAYER, method: "list", version: 3) {
                ("type", "all")
                ("additional", "subplayer_list")
            }
        )
        return result.players.filter(\.isPhysicalDevice)
    }

    /// 替换设备队列并从首曲起播。每次网络请求前检查调用方的会话/播放归属。
    /// 参数依据 Audio Station 7.2.1 网页 onPlayingQueueCommit / doJump。
    public func playQueue(
        deviceID: String, songIDs: [String], library: SynologyLibraryScope,
        password: String? = nil,
        validateContext: () async throws -> Void = {}
    ) async throws {
        guard !songIDs.isEmpty, songIDs.allSatisfy({ !$0.isEmpty }), !deviceID.isEmpty else {
            throw SynologyError.api(code: 101, message: "Remote playback requires a device and songs")
        }
        try Task.checkCancellation()
        try await validateContext()
        if let password, !password.isEmpty {
            let _: EmptyData = try await apiClient.request(
                ApiEndpoint(api: SynologyApi.AudioStation.REMOTE_PLAYER, method: "setpassword", version: 3, httpMethod: .post) {
                    ("id", deviceID)
                    ("password", password)
                }
            )
        }
        try Task.checkCancellation()
        try await validateContext()
        let queue: RemotePlayerQueue = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.REMOTE_PLAYER, method: "getplaylist", version: 3) {
                ("id", deviceID)
                ("offset", 0)
                ("limit", 0)
            }
        )
        try Task.checkCancellation()
        try await validateContext()
        let _: EmptyData = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.REMOTE_PLAYER, method: "updateplaylist", version: 3, httpMethod: .post) {
                ("id", deviceID)
                ("library", library.rawValue)
                ("offset", 0)
                ("limit", queue.total)
                ("songs", songIDs.map { $0.replacingOccurrences(of: ",", with: "\\,") }.joined(separator: ","))
                ("play", true)
                ("keep_shuffle_order", false)
            }
        )
        try Task.checkCancellation()
        try await validateContext()
        let _: EmptyData = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.REMOTE_PLAYER, method: "control", version: 3, httpMethod: .post) {
                ("id", deviceID)
                ("action", "play")
                ("value", 0)
            }
        )
    }

    public func stop(deviceID: String) async throws {
        let _: EmptyData = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.REMOTE_PLAYER, method: "control", version: 3, httpMethod: .post) {
                ("id", deviceID)
                ("action", "stop")
            }
        )
    }
}
