import Foundation

// MARK: - SynologyUserLoginProviding

/// 用户登录流程提供者协议
/// Protocol defining the user login flow interface
///
/// 内部依赖注入接口，由 `SynologyUserLogin` 实现，通过 `UserLoginFlowClient` 对外暴露。
/// Internal dependency injection interface, implemented by `SynologyUserLogin`, exposed via `UserLoginFlowClient`.
protocol SynologyUserLoginProviding {
    /// 使用账号密码进行登录
    /// Login with username and password
    /// - Parameters:
    ///   - server: QuickConnect ID 或自定义域名 / QuickConnect ID or custom domain
    ///   - username: 用户名 / Username
    ///   - password: 密码 / Password
    ///   - otpCode: 可选的 OTP 验证码 / Optional OTP code
    ///   - shouldSavePassword: 是否持久化保存密码 / Whether to persist password
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    func login(server: String, username: String, password: String, otpCode: String?, shouldSavePassword: Bool) -> AsyncStream<SynologyUserLoginProgress>

    /// 使用 Keychain 中保存的凭据进行静默恢复登录
    /// Resume login silently using credentials saved in Keychain
    ///
    /// 优先尝试 slice 登录（命中缓存 SID 时跳过完整登录的 round-trip）；
    /// 若 slice 校验失败（缓存 SID 已失效等），内部会自动 fallback 到全量密码登录。
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    func login() -> AsyncStream<SynologyUserLoginProgress>

    /// 使用 Keychain 中保存的凭据强制执行全量登录
    /// Force a full password re-login using credentials saved in Keychain
    ///
    /// 用于已知缓存 SID 失效的恢复路径（如 SessionOrchestrator 检测到 session fault 之后），
    /// 跳过 slice 校验直接执行 `SYNO.API.Auth.login`，避免一次注定失败的 round-trip。
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    func relogin() -> AsyncStream<SynologyUserLoginProgress>
}
