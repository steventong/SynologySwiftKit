# SynologySwiftKit

Swift package for building Synology DSM and Audio Station clients in Swift.

> Status: active development. The package is already usable, but API surface may still change as DSM and Audio Station coverage expands.

## Highlights

- Swift Concurrency-first API (`async/await`, `AsyncStream`)
- Built-in DSM modules: `auth`, `system`, `files`
- Audio Station modules: `albums`, `artists`, `composers`, `folders`, `genres`, `info`, `lyricsCatalog`, `pins`, `playlists`, `search`, `songs`, `playback`, `covers`, `tagEditor`
- Higher-level flows for login, connection check, and querying songs
- Customizable HTTP client and storage so integrators can adapt the package to their app architecture

## Requirements

- Swift 5.10+
- Xcode 15.4+
- iOS 13+
- macOS 10.15+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/steventong/SynologySwiftKit.git", branch: "develop")
]
```

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SynologySwiftKit", package: "SynologySwiftKit")
        ]
    )
]
```

## Quick Start

```swift
import SynologySwiftKit

let client = SynologyClient()

for await progress in await client.flows.auth.login(
    server: "your-quickconnect-id",
    usesHTTPS: true,
    username: "demo",
    password: "secret"
) {
    switch progress {
    case .connecting:
        print("Connecting...")
    case .authenticating:
        print("Authenticating...")
    case let .completed(result):
        print("Connected:", result.connection.url)
    case .otpRequired:
        print("OTP required")
    case let .failed(message), let .invalidSession(message):
        print("Login failed:", message)
    }
}
```

## Using Core APIs

```swift
import SynologySwiftKit

let client = SynologyClient()

let albums = try await client.audioStation.albums.list(limit: 20)
let songs = try await client.audioStation.songs.list(limit: 100, libraryScope: .shared)
let playlists = try await client.audioStation.playlists.list(limit: 50, offset: 0)
let smartPlaylist = try await client.audioStation.playlists.createSmart(
    name: "Top Picks",
    definition: SmartPlaylistDefinition(
        scope: .personal,
        matchRule: .all,
        serializedRules: "[]"
    )
)
let songCoverURL = try await client.audioStation.covers.songCoverURL(songID: "music_1", libraryScope: .shared)

print(albums.items.count)
print(songs.total)
print(playlists.items.map(\.name))
print(smartPlaylist.id)
print(songCoverURL)
```

## Dependency Injection

`SynologyClient` accepts custom storage and HTTP client implementations so the package can fit production apps and tests more naturally.

```swift
import SynologySwiftKit

struct MyHTTPClient: HTTPClientProtocol {
    func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse) {
        fatalError("Provide your own HTTP client")
    }
}

let client = SynologyClient(
    config: SynologyConfig(enableNetworkLogging: false),
    keyValueStorage: UserDefaultsStorage(userDefaults: .standard),
    keyChainStorage: KeyChainStorage(service: "com.example.synology"),
    httpClient: MyHTTPClient()
)
```

## Session Model

- `SynologyClient` restores persisted session state on initialization when available.
- `client.session.clear()` clears both in-memory and persisted session state.
- The default auth interceptor automatically attaches session credentials and clears persisted session state when DSM reports an expired session.

## Public Value Types

- `SynologyPage<Item>`: paged collection result
- `SynologySortDescriptor`: sort field plus sort direction
- `SynologyLibraryScope`: `.all`, `.shared`, `.personal`
- `SynologySession`, `SynologyConnection`, `SynologyCredentials`
- `SmartPlaylistDefinition`: typed input for smart playlist creation

## Stability Notes

- Consume `SynologySwiftKit` from the `develop` branch if you want the latest in-progress changes.
- Public API is still evolving while DSM and Audio Station endpoints are being added.
- If you adopt it in production, pin the exact revision in your app and review changelog-worthy updates before bumping.

## 技术方案

### 分层方案

| 层级 | 核心类型 | 主要职责 |
| --- | --- | --- |
| 公共入口层 | `SynologyClient` | 对外主入口、依赖装配、暴露领域化能力入口 |
| 功能与流程层 | `AuthClient`、`QuickConnectClient`、`AudioStationClient`、`FileStationClient`、`DSMInfoClient`、`EncryptionClient`、`SynologyUserLogin`、`CheckDeviceConnection`、`QueryAllSongs` | 单一服务域能力封装、跨 API 流程编排 |
| 领域层 | `SynologyConfig`、`SynologyError`、`ConnectionType`、`AuthResult`、`Song`、`Album`、`Playlist`、`AudioStationInfo`、`SynologyPage`、`SynologySortDescriptor`、`SynologyLibraryScope`、`SynologyCredentials`、`SmartPlaylistDefinition` | 对外稳定模型与错误语义 |
| 基础设施层 | `ApiClient`、`ApiEndpoint`、`HTTPClientProtocol`、`SwiftHttpClientAdapter`、`KeyValueStorage`、`KeyChainStorage` | 请求构建、请求发送、响应解码、错误映射、存储读写 |

### 模块职责

| 模块 / 类型 | 职责 |
| --- | --- |
| `SynologyClient` | 组合根；接收配置、storage、HTTP client；创建顶层能力入口并统一管理 session 恢复与清理 |
| `ApiClient` | 请求执行核心；解析 endpoint；拼接 query/body；执行内部鉴权链路；发送请求；解码响应；归一化错误 |
| `AuthClient` | 登录、登出、凭据读取 |
| `QuickConnectClient` | QuickConnect 解析、站点竞速、连接选择 |
| `AudioStationClient` | 聚合音乐相关子 API |
| `FileStationClient` | 文件相关接口 |
| `DSMInfoClient` | DSM 信息查询 |
| `EncryptionClient` | 加密相关接口 |
| `SynologyUserLogin` | 登录完整流程编排 |
| `CheckDeviceConnection` | 当前连接检查、连接刷新 |
| `QueryAllSongs` | 分页抓取歌曲并输出进度 |

### 对外能力

| 类型 | 暴露项 |
| --- | --- |
| 功能模块 | `auth`、`system`、`audioStation`、`files` |
| 流程模块 | `flows.auth`、`flows.connection`、`flows.library` |
| session 能力 | `session.connection`、`session.current`、`session.hasValidSession`、`session.update(sid:did:)`、`session.clear()` |
| 公共值类型 | `SynologyPage<Item>`、`SynologySortDescriptor`、`SynologyLibraryScope`、`SynologyCredentials`、`SynologyConnection`、`SynologySession`、`SmartPlaylistDefinition` |
| 扩展点 | `HTTPClientProtocol`、`KeyValueStorage`、`KeyChainStorage` |

### 依赖方案

| 上层 | 下层 |
| --- | --- |
| `SynologyClient` | 功能 API、流程对象、配置、HTTP client、storage |
| 流程对象 | 功能 API、能力协议、领域模型 |
| 功能 API | `ApiClientProviding`（模块内） |
| `ApiClient` | `HTTPClientProtocol`、内部 mapper、内部 endpoint 构建 |
| HTTP client 实现 | 第三方 HTTP 库 |

| 约束项 | 说明 |
| --- | --- |
| 流程对象依赖功能 API | 不直接持有第三方网络实现 |
| 功能 API 依赖 `ApiClientProviding` | 不直接依赖具体 HTTP client |
| 第三方 HTTP 库只出现在 HTTP client 适配层 | 当前为 `SwiftHttpClientAdapter` |
| storage 统一通过注入传递 | 不在流程内部重新创建默认实例 |

### 公共 API 边界

| 分类 | 类型范围 |
| --- | --- |
| 保留为 public | `SynologyClient`、功能 API、流程对象、领域模型、公共错误类型、HTTP client/storage 协议 |
| 保持 internal | 原始响应包装结构、endpoint 定义、内部错误映射器、内部常量、请求组装辅助类型、内部鉴权链路 |

### 状态方案

| 状态类型 | 归属位置 | 内容 |
| --- | --- | --- |
| 配置状态 | `SynologyConfig` | 超时、日志开关、缓存有效期 |
| 运行时状态 | `SynologyClient`、`ApiClient` | 当前连接、当前 session、当前 API 信息提供者 |
| 非敏感持久化状态 | `KeyValueStorage` | API info cache、Audio Station info cache、普通缓存数据 |
| 敏感持久化状态 | `KeyChainStorage` | credentials、session info、connection info、device info |

| 场景 | 动作 |
| --- | --- |
| `SynologyClient` 初始化 | 恢复已持久化 session |
| 登录成功 | 写入内存 session 和 keychain session |
| session 过期 | 默认 `AuthInterceptor` 清理内存与 keychain |
| 连接刷新成功 | 更新 `ApiClient` 当前连接并写入持久化 |

### 网络方案

| 阶段 | 实现 |
| --- | --- |
| 能力入口 | Feature API / Flow |
| 请求执行 | `ApiClient` |
| HTTP client 抽象 | `HTTPClientProtocol` |
| 默认 HTTP client 实现 | `SwiftHttpClientAdapter` |
| 第三方 HTTP 库 | `SwiftHttpClient` |

| `ApiClient` 处理项 | 内容 |
| --- | --- |
| endpoint 解析 | 解析 `ApiEndpoint` |
| URL 构建 | 生成标准请求地址 |
| 参数拼接 | 生成 GET query 和 POST body |
| 鉴权注入 | 注入 cookie 和 `_sid` |
| 内部鉴权链路 | 自动补充 cookie / `_sid` 并处理 session 失效清理 |
| 响应处理 | 解码 envelope 或原始响应 |
| 错误处理 | 映射 HTTP client / api / session 错误 |

### 并发与错误处理

| 项目 | 方案 |
| --- | --- |
| 并发模型 | Swift Concurrency |
| 流程对象 | 需要串行状态管理时使用 `actor` |
| 异步接口 | 统一使用 `async/await` |
| 进度输出 | 优先使用 `AsyncStream` |
| 数据跨并发边界 | 对公共领域类型标记 `Sendable` |

| 对外错误 | 说明 |
| --- | --- |
| `.network` | 网络 / HTTP client 错误 |
| `.api` | DSM / Audio Station API 错误 |
| `.sessionExpired` | session 失效 |
| `.auth` | 认证错误 |

### 测试方案

| 测试层 | 覆盖内容 | 依赖 |
| --- | --- | --- |
| 单元测试 | endpoint 构建、内部鉴权链路、storage、错误映射、工具函数 | mock HTTP client、mock storage、mock api client |
| 流程测试 | 登录流程、连接检查、session 恢复与清理、查询流程进度输出 | mock api client、mock keychain、mock user defaults |
| 集成测试 | 对接真实 Synology 环境的端到端行为 | 真实或受控 Synology 环境 |

### 当前实施状态

| 项目 | 状态 |
| --- | --- |
| `SynologyClient` 支持 HTTP client / storage 注入 | 已完成 |
| `HTTPClientProtocol` 作为 HTTP client 边界 | 已完成 |
| `SwiftHttpClientAdapter` 封装第三方网络实现 | 已完成 |
| `SynologyUserLogin` 复用注入的 storage | 已完成 |
| `CheckDeviceConnection` 复用注入的 keychain | 已完成 |
| session 自动恢复与自动清理链路 | 已完成 |
| README、SPI 配置、测试补齐 | 已完成 |

## Development

```bash
swift build
swift test
```

## Why This Package Exists

This package was extracted from the DS Music client app so DSM and Audio Station integration code can be reused outside the app itself.
