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
    ///   - usesHTTPS: 是否启用 HTTPS / Whether to use HTTPS
    ///   - username: 用户名 / Username
    ///   - password: 密码 / Password
    ///   - otpCode: 可选的 OTP 验证码 / Optional OTP code
    ///   - shouldSavePassword: 是否持久化保存密码 / Whether to persist password
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    func login(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String?, shouldSavePassword: Bool) -> AsyncStream<SynologyUserLoginProgress>

    /// 使用 Keychain 中保存的凭据进行静默恢复登录
    /// Resume login silently using credentials saved in Keychain
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    func login() -> AsyncStream<SynologyUserLoginProgress>
}
