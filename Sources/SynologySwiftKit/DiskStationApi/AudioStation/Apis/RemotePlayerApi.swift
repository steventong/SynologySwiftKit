import Foundation

/// 由 NAS 向 DLNA / AirPlay renderer 播放，客户端只发送控制命令。
public final class RemotePlayerApi {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) { self.apiClient = apiClient }

    /// 发现可单独投放的远程播放设备。
    ///
    /// GET SYNO.AudioStation.RemotePlayer/list，声明版本 3。
    ///
    /// 固定 type=all、additional=subplayer_list；过滤 __SYNO_WEB_PLAYER__ 和 __SYNO_Multiple_AirPlay__。模型只保留设备 ID、名称、类型、密码/seek/音量能力，未暴露子播放器详情。
    ///
    /// - Returns: [RemotePlayer]，来自 data.players。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func list() async throws -> [RemotePlayer] {
        let result: RemotePlayerList = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.REMOTE_PLAYER, method: "list", version: 3) {
                ("type", "all")
                ("additional", "subplayer_list")
            }
        )
        return result.players.filter(\.isPhysicalDevice)
    }

    /// 替换远程设备队列并从首曲播放。
    ///
    /// RemotePlayer v3：可选 setpassword POST → getplaylist GET → updateplaylist POST → control POST。
    ///
    /// getplaylist(offset=0,limit=0) 读取旧 total；updateplaylist(offset=0,limit=旧 total,play=true,keep_shuffle_order=false) 替换队列。流程不是事务，中途失败可能已修改设备状态。
    ///
    /// - Parameters:
    ///   - deviceID: NAS 返回的播放器 ID，不能为空。
    ///   - songIDs: 非空歌曲 ID 数组，每个 ID 必须非空；内部逗号转义为 \, 后再拼接。
    ///   - library: 发送 library 范围。
    ///   - password: 非空时先发送 setpassword；nil/空字符串跳过。
    ///   - validateContext: 每次请求前调用，供宿主检查会话和播放任务归属；默认不执行额外校验。
    /// - Returns: 无返回数据；最后一步 action=play,value=0 请求成功后结束。
    /// - Throws: 参数为空时本地抛出 api(code: 101)；取消、validateContext 和网络请求失败立即向上传递。
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

    /// 停止指定远程设备播放。
    ///
    /// POST SYNO.AudioStation.RemotePlayer/control，声明版本 3。
    ///
    /// 发送 action=stop；不清空队列。
    ///
    /// - Parameters:
    ///   - deviceID: 播放器 ID，发送为 id。
    /// - Returns: 无返回数据。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func stop(deviceID: String) async throws {
        let _: EmptyData = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.AudioStation.REMOTE_PLAYER, method: "control", version: 3, httpMethod: .post) {
                ("id", deviceID)
                ("action", "stop")
            }
        )
    }
}
