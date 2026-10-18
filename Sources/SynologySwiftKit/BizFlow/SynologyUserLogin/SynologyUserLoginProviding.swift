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
    ///   - sessionName: DSM 应用会话及权限校验使用的协议名称（不是 SID），必须与目标应用匹配，
    ///     例如 Audio Station 使用 `.audioStation`、File Station 使用 `.fileStation`、Video Station 使用 `.videoStation`。
    ///     不可任意填写或使用 App / SDK 名称；不匹配可能导致 SYNO.API.Auth.login 返回 402。
    ///     Use the target DSM application's session name, not an arbitrary product/SDK name or SID.
    ///   - server: QuickConnect ID 或自定义域名 / QuickConnect ID or custom domain
    ///   - username: 用户名 / Username
    ///   - password: 密码 / Password
    ///   - otpCode: 可选的 OTP 验证码 / Optional OTP code
    ///   - shouldSavePassword: 是否持久化保存密码 / Whether to persist password
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    func login(sessionName: SynologySessionName, server: String, username: String, password: String, otpCode: String?, shouldSavePassword: Bool) -> AsyncStream<SynologyUserLoginProgress>

    /// 使用 Keychain 中保存的凭据进行静默恢复登录
    /// Resume login silently using credentials saved in Keychain
    ///
    /// 优先校验保存的 SID；无 SID 或服务器明确判定会话失效时，使用密码登录。
    /// 网络、解码或取消错误结束本次恢复，并保留会话。
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    /// - Parameter sessionName: 与首次登录相同的 DSM 应用会话名称，不能改成 App / SDK 名称。
    func login(sessionName: SynologySessionName) -> AsyncStream<SynologyUserLoginProgress>

    /// 使用 Keychain 中保存的凭据强制执行全量登录
    /// Force a full password re-login using credentials saved in Keychain
    ///
    /// 发现连接并刷新 API 路由后，直接执行 `SYNO.API.Auth.login`。
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    /// - Parameter sessionName: 与首次登录相同的 DSM 应用会话名称，不能改成 App / SDK 名称。
    func relogin(sessionName: SynologySessionName) -> AsyncStream<SynologyUserLoginProgress>
}
