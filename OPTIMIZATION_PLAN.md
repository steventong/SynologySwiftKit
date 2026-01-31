# SynologySwiftKit 优化计划

> 基于行业最佳实践的全面优化建议，涵盖架构设计到具体实现细节。

---

## 目录

1. [架构层优化](#1-架构层优化)
2. [代码质量优化](#2-代码质量优化)
3. [安全性优化](#3-安全性优化)
4. [性能优化](#4-性能优化)
5. [可维护性优化](#5-可维护性优化)
6. [测试优化](#6-测试优化)
7. [文档优化](#7-文档优化)

---

## 1. 架构层优化

### 1.1 ✅ ~~移除未使用的 SwiftyJSON 依赖~~ (已完成)

**文件**: `Package.swift`  
**现状**: 依赖了 SwiftyJSON，但实际代码全部使用原生 `Codable`。  
**建议**: 移除 SwiftyJSON 依赖，保持依赖最小化。

```diff
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", ...),
-   .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", ...)
]
```

---

### 1.2 ✅ ~~依赖注入替代单例模式~~ (已完成 - 彻底移除单例)

**文件**: `DeviceConnection.swift`, `ApiInfoApi.swift`, `ApiClient.swift`, `CheckDeviceConnection.swift`  
**现状**: ✅ 已彻底移除所有 `.shared` 单例，实施完整依赖注入。

**已实现**:
- ✅ 创建了 `SynologyClient` 统一服务容器
- ✅ 创建 `DeviceConnectionProviding` 协议
- ✅ 创建 `ApiClientProviding` 协议  
- ✅ 创建 `ApiInfoProviding` 协议
- ✅ **彻底移除** `DeviceConnection.shared`, `ApiClient.shared`, `ApiInfoApi.shared`, `CheckDeviceConnection.shared`
- ✅ `SynologyUserLogin` 和 `CheckDeviceConnection` 完全使用依赖注入
- ✅ 所有 AudioStation API 类使用注入的 `apiClient`
- ✅ 解决了 `ApiClient` ↔ `ApiInfoApi` 循环依赖（延迟注入模式）

```swift
// 新的使用方式
let client = SynologyClient()
try await client.audioStation.songList(limit: 100)
client.deviceConnection.updateLoginSession(...)
```

> [⚠️ WARNING]
> **Breaking Change**: 旧的 `.shared` 单例损问已不再可用，必须迁移到 `SynologyClient`。

---

### 1.3 ✅ ~~创建统一的 API Client 层~~ (已完成)

**文件**: `SynologyClient.swift`  
**现状**: ✅ 已创建 `SynologyClient` 统一管理所有依赖和 API 模块。

```swift
public final class SynologyClient {
    // 核心服务
    public let deviceConnection: DeviceConnection
    let apiClient: ApiClient
    public let apiInfo: ApiInfoApi
    
    // API 模块
    public lazy var audioStation: AudioStationApi
    public lazy var auth: AuthApi
    public lazy var quickConnect: QuickConnectApi
    public lazy var dsmInfo: DsmInfoApi
    public lazy var encryption: EncryptionApi
    
    // 业务流程
    public lazy var userLogin: SynologyUserLogin
    public lazy var checkConnection: CheckDeviceConnection
    
    public init() {
        self.deviceConnection = DeviceConnection()
        self.apiClient = ApiClient(connectionProvider: deviceConnection)
        self.apiInfo = ApiInfoApi(apiClient: apiClient)
        self.apiClient.apiInfoProvider = apiInfo  // 解决循环依赖
    }
}
```

---

### 1.4 ✅ ~~统一错误处理架构~~ (已完成)

**文件**: `SynologyError.swift`  
**现状**: ✅ 已创建层级化的 `SynologyError` 统一所有错误类型。

**已实现**:
- ✅ 创建 `SynologyError` 层级化错误枚举
- ✅ 包含 `NetworkError`、`ApiError`、`AuthError`、`QuickConnectError`、`ConnectionError` 子类型
- ✅ 更新 `ApiClient`、`AuthApi`、`QuickConnectApi` 等使用新错误类型
- ✅ 将 `SynologyApiResponse` 中的 `SynologyError` struct 重命名为 `SynologyApiError`

```swift
public enum SynologyError: Error, LocalizedError {
    case network(NetworkError)
    case api(ApiError)
    case auth(AuthError)
    case quickConnect(QuickConnectError)
    case connection(ConnectionError)
}

// 使用示例
do {
    try await client.auth.login(...)
} catch SynologyError.auth(.otpRequired) {
    // 需要两步验证
} catch SynologyError.api(.invalidSession) {
    // 会话过期
}
```

```swift
public enum SynologyError: Error, LocalizedError {
    case network(NetworkError)
    case api(ApiError)
    case auth(AuthError)
    case quickConnect(QuickConnectError)
    
    public enum NetworkError {
        case sslFailed(String)
        case hostNotFound(String)
        case timeout
        case connectionFailed(underlying: Error)
    }
    
    public enum ApiError {
        case invalidSession(code: Int, message: String)
        case apiNotExists(name: String)
        case businessError(code: Int, message: String)
        case responseEmpty
    }
    
    public enum AuthError {
        case invalidCredentials
        case accountDisabled
        case otpRequired
        case otpFailed
        case sessionExpired
    }
}
```

---

### 1.5 ✅ ~~重构 API 定义枚举~~ (已完成)

**文件**: `SynologyApi.swift`, `DiskStationApiDefine.swift`  
**现状**: ✅ 已创建命名空间结构的 `SynologyApi`，旧枚举标记为 deprecated。

**已实现**:
- ✅ 创建 `ApiDefinition` 结构体
- ✅ 创建 `SynologyApi` 命名空间（Core、AudioStation、FileStation）
- ✅ 标记 `DiskStationApiDefine` 为 `@deprecated`
- ✅ 删除注释掉的代码

```swift
// 新的使用方式
let endpoint = ApiEndpoint(
    api: SynologyApi.AudioStation.song,
    method: "list",
    parameters: ["limit": 100]
)
```
```

---

### 1.6 ✅ ~~项目结构重组~~ (已评估 - 保持现状)

**现状**: 当前结构已基本合理，保持不变。

```
Sources/SynologySwiftKit/
├── BizFlow/          (业务流程)
├── Common/           (通用组件)
├── DiskStationApi/   (API 模块)
└── SynologyClient.swift
```

**决策**: 大规模重组风险高（需更新所有 import），现有结构可满足需求。
├── APIs/
│   ├── Core/           (Auth, ApiInfo, Encryption, DsmInfo)
│   ├── AudioStation/
│   ├── FileStation/
│   └── QuickConnect/
├── Models/
│   ├── Connection.swift
│   ├── Session.swift
│   └── Errors.swift
├── Services/
│   ├── ConnectionService.swift
│   └── LoginService.swift
├── Storage/
│   ├── KeychainStorage.swift
│   └── CacheStorage.swift
└── Utils/
    └── Logger.swift
```

---

## 2. 代码质量优化

### 2.1 ✅ ~~模型属性命名规范化~~ (已完成)

**文件**: `SongModels.swift`, `PlaylistModels.swift` 等  
**现状**: ✅ 已全部重命名为驼峰命名，并添加了 `CodingKeys`。全部模型已迁移。

```swift
// 当前代码
public struct SongAdditional: Codable {
    public var song_audio: SongAudio?    // ❌ snake_case
    public var song_rating: SongRating?
    public var song_tag: SongTag?
}
```

**建议**: 使用 CodingKeys 映射：

```swift
public struct SongAdditional: Codable {
    public var audio: SongAudio?
    public var rating: SongRating?
    public var tag: SongTag?
    
    private enum CodingKeys: String, CodingKey {
        case audio = "song_audio"
        case rating = "song_rating"
        case tag = "song_tag"
    }
}
```

---

### 2.2 ✅ ~~方法命名规范化~~ (已完成)

**文件**: `PlaylistApi.swift`, `TagEditorApi.swift`  
**现状**: ✅ 已将所有公共 API 方法重命名为 camelCase (如 `createPlaylist`, `tagEditorLoad`)。

```swift
// 当前代码
public func playlist_create(name: String, ...) // ❌ snake_case
public func playlist_rename(id: String, ...) // ❌ snake_case
public func playlist_delete(id: String) // ❌ snake_case
public func playlistAddSongs(id: String, ...) // ✅ camelCase
```

**建议**: 统一使用驼峰命名：

```swift
public func createPlaylist(name: String, library: String, songs: [String]?) async throws -> String
public func renamePlaylist(id: String, newName: String) async throws -> String
public func deletePlaylist(id: String) async throws -> Bool
public func addSongsToPlaylist(id: String, songs: [String]) async throws -> Bool
```

---

### 2.3 ✅ ~~使用 Result Builder 简化参数构建~~ (已完成)

**文件**: `SongApi.swift`, `ApiParametersBuilder.swift`  
**现状**: ✅ 已通过 `ApiParametersBuilder` 和扩展 `ApiEndpoint` 实现声明式参数构建。

```swift
// 当前代码 (SongApi.swift:39-77)
var parameters: [String: Any] = [...]
if let artist { parameters["artist"] = artist }
if let album { parameters["album"] = album }
if let album_artist { parameters["album_artist"] = album_artist }
// ... 更多 if let
```

**建议**: 使用 Result Builder：

```swift
@resultBuilder
public struct ParameterBuilder {
    public static func buildBlock(_ components: (String, Any?)...) -> [String: Any] {
        components.reduce(into: [:]) { result, pair in
            if let value = pair.1 {
                result[pair.0] = value
            }
        }
    }
}

// 使用
@ParameterBuilder
var parameters: [String: Any] {
    ("library", library)
    ("limit", limit)
    ("offset", offset)
    ("artist", artist)
    ("album", album)
    ("additional", additional)
}
```

---

### 2.4 ✅ ~~错误码映射优化~~ (已完成)

**文件**: `ApiClient.swift`, `SynologyErrorMapper.swift`  
**现状**: ✅ 引入 `SynologyErrorMapper`，支持错误码到本地化字符串的自动映射。已移除旧的 `DiskStationApiError`。

**建议**: 使用字典映射：

```swift
private let commonErrorMessages: [Int: String] = [
    100: "Unknown error.",
    101: "No parameter of API, method or version.",
    102: "The requested API does not exist.",
    103: "The requested method does not exist.",
    104: "The requested version does not support the functionality.",
    // ...
]

private let sessionErrorCodes: Set<Int> = [105, 106, 107, 119]

private func handleErrorCode(_ code: Int) throws {
    if sessionErrorCodes.contains(code) {
        throw SynologyError.api(.invalidSession(code: code, message: commonErrorMessages[code] ?? "Session error"))
    }
    throw SynologyError.api(.businessError(code: code, message: commonErrorMessages[code] ?? "Error code: \(code)"))
}
```

---

### 2.5 ✅ ~~文件命名规范~~ (已完成)

**文件**: 所有模型文件  
**现状**: ✅ 已将如 `AuthApiModels.swift` 等重命名为 `AuthModels.swift`，确保格式统一。

| 当前 | 建议 |
|------|------|
| 文件头注释 `File.swift` | 更新为实际文件名 |

---

### 2.6 ✅ ~~移除注释掉的代码~~ (已完成)

**文件**: `DiskStationApiDefine.swift`, `DiskStationApiError.swift`  
**现状**: ✅ 已删除 `DiskStationApiDefine.swift` 和 `DiskStationApiError.swift`。

```swift
// DiskStationApiDefine.swift:157-195
//    var apiPath: String {
//        switch self {
//        case .SYNO_API_INFO:
//            return "/webapi/query.cgi"
//        ...
```

**建议**: 如需保留历史，使用 Git；否则删除。

---

### 2.7 🟢 使用类型别名简化复杂类型

**文件**: `DeviceConnection.swift`, `QuickConnectApi.swift`  
**现状**: 多处使用复杂元组类型。

```swift
// 当前代码
func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)?
func getLoginSession() -> (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)?
```

**建议**: 定义专用类型：

```swift
public struct ConnectionInfo {
    public let type: ConnectionType
    public let url: String
}

public struct SessionInfo {
    public let sid: String
    public let sidExpireAt: Date
    public let did: String?
    public let didExpireAt: Date?
    
    public var isExpired: Bool {
        Date() > sidExpireAt
    }
}
```

---

### 2.8 🟢 添加访问控制

**文件**: 多个文件  
**现状**: 部分内部类型和方法缺少 `private` 或 `internal` 标记。

**建议**: 明确标记所有访问级别：

```swift
// 内部使用的类型
internal struct DiskStationApiResult<T: Decodable>: Decodable { ... }

// 公开 API
public func songList(...) async throws -> (total: Int, data: [Song])
```

---

## 3. 安全性优化

### 3.1 🔴 使用 Keychain 存储敏感数据

**文件**: `DeviceConnection.swift`  
**现状**: 敏感数据（sid, did, deviceId）存储在 UserDefaults。

```swift
// 当前代码 (DeviceConnection.swift:107-116)
UserDefaults.standard.setValue(sid, forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName)
```

**建议**: 实现 Keychain 存储：

```swift
import Security

public final class KeychainStorage {
    private let service: String
    
    public init(service: String = "me.itwl.SynologySwiftKit") {
        self.service = service
    }
    
    public func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    public func load(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { return nil }
            throw KeychainError.loadFailed(status)
        }
        
        return result as? Data
    }
    
    public func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
}
```

---

### 3.2 🟡 避免日志记录敏感信息

**文件**: `AuthApi.swift`, `DeviceConnection.swift`  
**现状**: 日志中可能包含敏感信息。

```swift
// 当前代码
Logger.info("authResult: \(authResult)")  // 可能包含 sid, did
Logger.debug("update login session, session: \(session)")
```

**建议**: 对敏感信息脱敏：

```swift
extension AuthResult: CustomStringConvertible {
    public var description: String {
        "AuthResult(sid: \(sid.prefix(8))..., did: \(did?.prefix(8) ?? "nil")...)"
    }
}
```

---

## 4. 性能优化

### 4.1 ✅ ~~API Info 缓存优化~~ (已完成)

**文件**: `ApiInfoApi.swift`  
**现状**: ✅ 已实现基于 Host 的缓存隔离，防止多 NAS 冲突。

```swift
// 当前代码 (ApiInfoApi.swift:22-26)
if cachedApiInfo.isEmpty,
   let cachedApiInfo = getApiInfoFromUserDefaults() {
    self.cachedApiInfo = cachedApiInfo
}
```

**建议**: 使用内存缓存 + 懒加载：

```swift
private lazy var cachedApiInfo: [String: ApiInfoNode] = {
    getApiInfoFromUserDefaults() ?? [:]
}()
```

---

### 4.2 🟡 连接复用优化

**文件**: `AlamofireClientFactory.swift`  
**现状**: 缺少 HTTP/2 和连接池配置。

**建议**:

```swift
static func createSession(
    timeoutIntervalForRequest: TimeInterval,
    trustedSSLDomain: String? = nil
) -> Session {
    let configuration = URLSessionConfiguration.af.default
    configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
    configuration.timeoutIntervalForResource = 60
    configuration.httpMaximumConnectionsPerHost = 6
    configuration.urlCache = URLCache(
        memoryCapacity: 10 * 1024 * 1024,
        diskCapacity: 50 * 1024 * 1024
    )
    // ...
}
```

---

### 4.3 🟢 减少字符串拼接

**文件**: `QuickConnectApi.swift`  
**现状**: 多处使用字符串插值拼接 URL。

```swift
// 当前代码
"\(httpScheme)\(host):\(port)"
```

**建议**: 使用 URLComponents：

```swift
private func buildConnectionURL(scheme: String, host: String, port: Int) -> String? {
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    components.port = port
    return components.string
}
```

---

## 5. 可维护性优化

### 5.1 🟡 使用 Swift 新特性

**文件**: `Package.swift`  
**现状**: 使用 Swift 5.10，可启用更多现代特性。

**建议**: 启用严格并发检查：

```swift
.target(
    name: "SynologySwiftKit",
    dependencies: [...],
    swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
    ]
)
```

---

### 5.2 🟡 增强 Logger 功能

**文件**: `Logger.swift`  
**现状**: 基础日志功能，使用过时的 `os_log` API。

**建议**: 升级到 Swift Logger API：

```swift
import OSLog

public enum Log {
    private static let subsystem = "me.itwl.SynologySwiftKit"
    
    public static let network = Logger(subsystem: subsystem, category: "Network")
    public static let auth = Logger(subsystem: subsystem, category: "Auth")
    public static let api = Logger(subsystem: subsystem, category: "API")
    public static let quickConnect = Logger(subsystem: subsystem, category: "QuickConnect")
}

// 使用
Log.network.info("Connection established: \(url)")
Log.auth.error("Login failed: \(error)")
```

---

### 5.3 🟢 ConnectionType 优化

**文件**: `CoreModels.swift`  
**现状**: `getByName` 方法与 `name` 属性重复逻辑。

```swift
// 当前代码
public static func getByName(name: String) -> ConnectionType? {
    switch name {
    case "lan": .lan
    case "ddns": .ddns
    // ...
    }
}

public var name: String {
    switch self {
    case .lan: "lan"
    case .ddns: "ddns"
    // ...
    }
}
```

**建议**: 使用 RawRepresentable：

```swift
public enum ConnectionType: String, CaseIterable, Codable {
    case lan
    case wan
    case lanv6
    case wanv6
    case ddns
    case relay
    case customDomain = "custom_domain"
    
    static var ordered: [ConnectionType] {
        [.lan, .wan, .lanv6, .wanv6, .ddns, .relay, .customDomain]
    }
}
```

---

## 6. 测试优化

### 6.1 🟡 添加单元测试基础设施

**文件**: `Tests/SynologySwiftKitTests/`  
**现状**: 主要是依赖真实服务器的集成测试。

**建议**: 添加 Mock 支持：

```swift
// MockURLProtocol.swift
final class MockURLProtocol: URLProtocol {
    static var responseHandler: ((URLRequest) -> (Data?, HTTPURLResponse?, Error?))?
    
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        guard let handler = Self.responseHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        
        let (data, response, error) = handler(request)
        
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response = response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    override func stopLoading() {}
}

// TestHelpers.swift
func makeTestSession() -> Session {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return Session(configuration: configuration)
}
```

---

### 6.2 🟢 添加测试用例覆盖

**建议测试场景**:

- [ ] API 请求成功解析
- [ ] API 请求失败处理
- [ ] Session 过期重新认证
- [ ] QuickConnect 地址解析
- [ ] 多种连接类型优先级
- [ ] 错误码映射正确性

---

## 7. 文档优化

### 7.1 🟡 添加 DocC 文档

**文件**: 所有公开 API  
**建议**: 为公开 API 添加完整文档注释：

```swift
/// 查询歌曲列表
///
/// 从指定音乐库中获取歌曲列表，支持多种过滤和排序条件。
///
/// - Parameters:
///   - limit: 每页数量，默认 100，最大 100000
///   - offset: 偏移量，默认 0
///   - library: 音乐库类型，可选值：`"shared"`（共享）或 `"personal"`（个人）
///   - artist: 按艺术家过滤
///   - album: 按专辑过滤
///   - sort: 排序规则元组 `(sort_by, sort_direction)`
///
/// - Returns: 包含总数和歌曲数组的元组
///
/// - Throws: `SynologyError.api` 当 API 请求失败时
///           `SynologyError.network` 当网络连接失败时
///
/// - Example:
///   ```swift
///   let (total, songs) = try await api.songList(
///       limit: 50,
///       artist: "周杰伦",
///       sort: ("song_rating", "DESC")
///   )
///   ```
public func songList(
    limit: Int = 100,
    offset: Int = 0,
    library: String = "shared",
    artist: String? = nil,
    album: String? = nil,
    sort: (sort_by: String, sort_direction: String)? = nil
) async throws -> (total: Int, data: [Song])
```

---

### 7.2 🟡 完善 README

**文件**: `README.md`  
**建议内容**:

- 功能特性列表
- 安装指南（SPM）
- 快速开始示例代码
- API 参考链接
- 贡献指南
- 许可证说明

---

## 优先级总结

| 优先级 | 类别 | 优化项 | 预估工作量 |
|--------|------|--------|------------|
| ✅ | 架构 | ~~移除 SwiftyJSON~~ | ~~0.5h~~ |
| ✅ | 架构 | ~~依赖注入替代单例~~ | ~~4h~~ |
| ✅ | 架构 | ~~创建统一 API Client~~ | ~~3h~~ |
| 🔴 | 代码 | 模型属性命名规范化 | 2h |
| 🔴 | 代码 | 方法命名规范化 | 1h |
| 🔴 | 安全 | Keychain 存储敏感数据 | 2h |
| 🟡 | 架构 | 统一错误处理 | 3h |
| 🟡 | 架构 | 重构 API 定义枚举 | 2h |
| 🟡 | 代码 | Result Builder 参数构建 | 2h |
| 🟡 | 代码 | 错误码映射优化 | 1h |
| 🟡 | 安全 | 日志脱敏 | 1h |
| 🟡 | 性能 | API Info 缓存优化 | 1h |
| 🟡 | 可维护 | Logger 功能增强 | 1h |
| 🟡 | 可维护 | 启用严格并发检查 | 2h |
| 🟡 | 测试 | 添加 Mock 测试基础设施 | 3h |
| 🟡 | 文档 | DocC 文档 | 4h |
| 🟡 | 文档 | 完善 README | 2h |
| 🟢 | 架构 | 项目结构重组 | 4h |
| 🟢 | 代码 | 移除注释代码 | 0.5h |
| 🟢 | 代码 | 类型别名简化 | 1h |
| 🟢 | 代码 | 添加访问控制 | 1h |
| 🟢 | 代码 | 文件命名规范 | 0.5h |
| 🟢 | 性能 | 连接复用优化 | 1h |
| 🟢 | 性能 | URL 构建优化 | 0.5h |
| 🟢 | 可维护 | ConnectionType 优化 | 0.5h |
| 🟢 | 测试 | 补充测试用例 | 4h |

---

## 实施建议

1. **第一阶段（高优先级）**: 先完成安全性和代码规范优化
2. **第二阶段（架构优化）**: 逐步引入依赖注入和统一 Client
3. **第三阶段（可维护性）**: 完善文档和测试覆盖
4. **持续优化**: 根据实际需求调整优先级

---

> 如需针对某项优化的详细实施方案，请告诉我！
