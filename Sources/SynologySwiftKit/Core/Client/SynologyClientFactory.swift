import Foundation

// MARK: - SynologyClientFactory

/// `SynologyClient` 工厂方法（便捷创建入口）
/// Factory methods for creating `SynologyClient` instances
///
/// 提供两种常见场景的便捷初始化方式：
/// Provides convenient initializers for two common scenarios:
/// - 全新客户端（需要走登录流程）/ Fresh client (requires login flow)
/// - 已有 Session 的客户端（绕过登录直接调用 API）/ Client with existing session (skip login)
public enum SynologyClientFactory {

    /// 创建标准 Synology 客户端
    /// Create a standard Synology client
    ///
    /// - Parameters:
    ///   - config: 全局配置，默认使用 `SynologyConfig.default` / Global config, default: `SynologyConfig.default`
    ///   - keyValueStorage: 非敏感缓存存储，默认使用 `UserDefaultsStorage` / Non-sensitive cache storage, default: `UserDefaultsStorage`
    ///   - keyChainStorage: 敏感信息存储，默认使用 `KeyChainStorage` / Sensitive storage, default: `KeyChainStorage`
    ///   - httpClient: HTTP 客户端实现，默认使用 `URLSessionHTTPClient` / HTTP client implementation, default: `URLSessionHTTPClient`
    ///   - autoRegisterAuthInterceptor: 是否自动注册鉴权拦截器，默认 true / Auto-register auth interceptor, default: true
    /// - Returns: 配置好的 `SynologyClient` 实例 / Configured `SynologyClient` instance
    public static func make(
        config: SynologyConfig = .default,
        keyValueStorage: KeyValueStorage = UserDefaultsStorage(),
        keyChainStorage: any SensitiveStorage = KeyChainStorage(),
        httpClient: HTTPClientProtocol = URLSessionHTTPClient(),
        autoRegisterAuthInterceptor: Bool = true
    ) -> SynologyClient {
        SynologyClient(
            config: config,
            keyValueStorage: keyValueStorage,
            keyChainStorage: keyChainStorage,
            httpClient: httpClient,
            autoRegisterAuthInterceptor: autoRegisterAuthInterceptor
        )
    }

    /// 创建携带已有 Session 的 Synology 客户端（跳过登录）
    /// Create a Synology client with an existing session (skip login flow)
    ///
    /// 适用场景：宿主 App 自行持久化了连接地址和 Session，重新启动时直接恢复。
    /// Use case: the host app persists connection and session externally and restores on relaunch.
    ///
    /// - Parameters:
    ///   - connectionType: 连接类型 / Connection type
    ///   - url: 服务器地址 / Server URL
    ///   - sid: 会话 ID / Session ID
    ///   - did: 设备 ID（可选）/ Device ID (optional)
    ///   - config: 全局配置 / Global config
    ///   - keyValueStorage: 非敏感缓存存储 / Non-sensitive cache storage
    ///   - keyChainStorage: 敏感信息存储 / Sensitive storage
    ///   - httpClient: HTTP 客户端实现 / HTTP client implementation
    /// - Returns: 已注入 Session 的 `SynologyClient` 实例 / `SynologyClient` with injected session
    public static func makeWithExistingSession(
        connectionType: ConnectionType,
        url: String,
        sid: String,
        did: String? = nil,
        config: SynologyConfig = .default,
        keyValueStorage: KeyValueStorage = UserDefaultsStorage(),
        keyChainStorage: any SensitiveStorage = KeyChainStorage(),
        httpClient: HTTPClientProtocol = URLSessionHTTPClient()
    ) -> SynologyClient {
        let client = make(
            config: config,
            keyValueStorage: keyValueStorage,
            keyChainStorage: keyChainStorage,
            httpClient: httpClient
        )
        client.configureConnection(type: connectionType, url: url, sid: sid, did: did)
        return client
    }
}
