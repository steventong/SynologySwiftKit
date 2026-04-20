# SynologySwiftKit 技术方案

## 1. 方案范围

本文档只描述 `SynologySwiftKit` 的技术方案，不讨论原理性设计说明。

当前方案覆盖：

| 项目 | 内容 |
| --- | --- |
| 模块结构 | 分层、模块职责、依赖方向 |
| 运行时 | 状态归属、存储归属、session 管理 |
| 基础设施 | 网络发送、内部鉴权链路、日志、错误处理 |
| 工程化 | 测试分层、目录结构、实施项 |

## 2. 分层方案

| 层级 | 核心类型 | 主要职责 |
| --- | --- | --- |
| 公共入口层 | `SynologyClient` | 对外主入口、依赖装配、暴露领域化能力入口 |
| 功能与流程层 | `AuthClient`、`QuickConnectClient`、`AudioStationClient`、`FileStationClient`、`DSMInfoClient`、`EncryptionClient`、`SynologyUserLogin`、`CheckDeviceConnection`、`QueryAllSongs` | 单一服务域能力封装、跨 API 流程编排 |
| 领域层 | `SynologyConfig`、`SynologyError`、`ConnectionType`、`ServerType`、`AuthResult`、`Song`、`Album`、`Playlist`、`AudioStationInfo`、`SynologyPage`、`SynologySortDescriptor`、`SynologyLibraryScope`、`SynologyCredentials`、`SmartPlaylistDefinition` | 对外稳定模型与错误语义 |
| 基础设施层 | `ApiClient`、`ApiEndpoint`、`HTTPClientProtocol`、`SwiftHttpClientAdapter`、`KeyValueStorage`、`KeyChainStorage` | 请求构建、请求发送、响应解码、错误映射、存储读写 |

## 3. 模块职责方案

### 3.1 核心模块职责

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

### 3.2 SynologyClient 对外暴露能力

| 类型 | 暴露项 |
| --- | --- |
| 功能模块 | `auth`、`system`、`audioStation`、`files` |
| 流程模块 | `flows.auth`、`flows.connection`、`flows.library` |
| session 能力 | `session.connection`、`session.current`、`session.hasValidSession`、`session.update(sid:did:)`、`session.clear()` |
| 公共值类型 | `SynologyPage<Item>`、`SynologySortDescriptor`、`SynologyLibraryScope`、`SynologyCredentials`、`SynologyConnection`、`SynologySession`、`SmartPlaylistDefinition` |
| 扩展点 | `HTTPClientProtocol`、`KeyValueStorage`、`KeyChainStorage` |

## 4. 依赖方案

### 4.1 依赖方向

| 上层 | 下层 |
| --- | --- |
| `SynologyClient` | 功能 API、流程对象、配置、transport、storage |
| 流程对象 | 功能 API、能力协议、领域模型 |
| 功能 API | `ApiClientProviding`（模块内） |
| `ApiClient` | `HTTPClientProtocol`、内部 mapper、内部 endpoint 构建 |
| transport 实现 | 第三方 HTTP 库 |

### 4.2 依赖约束

| 约束项 | 说明 |
| --- | --- |
| 流程对象依赖功能 API | 不直接持有第三方网络实现 |
| 功能 API 依赖 `ApiClientProviding` | 不直接依赖具体 transport |
| 第三方 HTTP 库只出现在 HTTP client 适配层 | 当前为 `SwiftHttpClientAdapter` |
| storage 统一通过注入传递 | 不在流程内部重新创建默认实例 |

## 5. 公共 API 方案

| 分类 | 类型范围 |
| --- | --- |
| 保留为 public | `SynologyClient`、功能 API、流程对象、领域模型、公共错误类型、transport/storage 协议 |
| 保持 internal | 原始响应包装结构、endpoint 定义、内部错误映射器、内部常量、请求组装辅助类型、内部鉴权链路 |

## 6. 状态方案

### 6.1 状态归属

| 状态类型 | 归属位置 | 内容 |
| --- | --- | --- |
| 配置状态 | `SynologyConfig` | 超时、日志开关、缓存有效期 |
| 运行时状态 | `SynologyClient`、`ApiClient` | 当前连接、当前 session、当前 API 信息提供者 |
| 非敏感持久化状态 | `KeyValueStorage` | API info cache、Audio Station info cache、普通缓存数据 |
| 敏感持久化状态 | `KeyChainStorage` | credentials、session info、connection info、device info |

### 6.2 状态同步链路

| 场景 | 动作 |
| --- | --- |
| `SynologyClient` 初始化 | 恢复已持久化 session |
| 登录成功 | 写入内存 session 和 keychain session |
| session 过期 | 默认 `AuthInterceptor` 清理内存与 keychain |
| 连接刷新成功 | 更新 `ApiClient` 当前连接并写入持久化 |

## 7. 网络方案

### 7.1 请求链路

| 阶段 | 实现 |
| --- | --- |
| 能力入口 | Feature API / Flow |
| 请求执行 | `ApiClient` |
| HTTP client 抽象 | `HTTPClientProtocol` |
| 默认 HTTP client 实现 | `SwiftHttpClientAdapter` |
| 第三方 HTTP 库 | `SwiftHttpClient` |

### 7.2 ApiClient 处理项

| 处理项 | 内容 |
| --- | --- |
| endpoint 解析 | 解析 `ApiEndpoint` |
| URL 构建 | 生成标准请求地址 |
| 参数拼接 | 生成 GET query 和 POST body |
| 鉴权注入 | 注入 cookie 和 `_sid` |
| 内部鉴权链路 | 自动补充 cookie / `_sid` 并处理 session 失效清理 |
| 响应处理 | 解码 envelope 或原始响应 |
| 错误处理 | 映射 transport / api / session 错误 |

### 7.3 内部鉴权方案

| 类型 | 说明 |
| --- | --- |
| `AuthInterceptor` | 模块内部默认鉴权链路，自动补充 session，处理 session 过期清理 |

## 8. 并发方案

| 项目 | 方案 |
| --- | --- |
| 并发模型 | Swift Concurrency |
| 流程对象 | 需要串行状态管理时使用 `actor` |
| 异步接口 | 统一使用 `async/await` |
| 进度输出 | 优先使用 `AsyncStream` |
| 数据跨并发边界 | 对公共领域类型标记 `Sendable` |

## 9. 错误处理方案

### 9.1 对外错误类型

| 类型 | 说明 |
| --- | --- |
| `.network` | 网络 / transport 错误 |
| `.api` | DSM / Audio Station API 错误 |
| `.sessionExpired` | session 失效 |
| `.auth` | 认证错误 |

### 9.2 错误处理链路

| 阶段 | 动作 |
| --- | --- |
| 响应解码 | 解码原始错误结构 |
| 内部归一化 | 由 `ApiClient` 或 mapper 转换成 `SynologyError` |
| 流程层处理 | 根据错误类型转成流程状态，或继续向外抛出 |

## 10. 日志方案

| 项目 | 方案 |
| --- | --- |
| 日志入口 | `Logger` |
| 底层实现 | `OSLog` |
| 开关来源 | `SynologyConfig.enableNetworkLogging` |
| 记录范围 | 请求关键分支、连接选择、登录流程、缓存命中与失败 |

## 11. 测试方案

### 11.1 测试分层

| 测试层 | 覆盖内容 | 依赖 |
| --- | --- | --- |
| 单元测试 | endpoint 构建、内部鉴权链路、storage、错误映射、工具函数 | mock transport、mock storage、mock api client |
| 流程测试 | 登录流程、连接检查、session 恢复与清理、查询流程进度输出 | mock api client、mock keychain、mock user defaults |
| 集成测试 | 对接真实 Synology 环境的端到端行为 | 真实或受控 Synology 环境 |

### 11.2 当前状态

| 项目 | 状态 |
| --- | --- |
| 本地 / PR 校验 | 以单元测试和流程测试为主 |
| 集成测试 | 非必需项，可后续单独扩展 |

## 12. 仓库目录方案

```text
Sources/
  SynologySwiftKit/
    Client/
      SynologyClient.swift
    Domain/
      Models/
      Errors/
      Config/
    Features/
      Auth/
      QuickConnect/
      AudioStation/
      FileStation/
    Flows/
      SynologyUserLogin/
      CheckDeviceConnection/
      QueryAllSongs/
    Infrastructure/
      Transport/
      Storage/
      Logging/
      ApiCore/
      Interceptors/
    Resources/

Tests/
  SynologySwiftKitTests/
    Unit/
    Flows/
    Integration/
```

## 13. 当前实施项

| 项目 | 状态 |
| --- | --- |
| `SynologyClient` 支持 transport / storage 注入 | 已完成 |
| `HTTPClientProtocol` 作为 HTTP client 边界 | 已完成 |
| `SwiftHttpClientAdapter` 封装第三方网络实现 | 已完成 |
| `SynologyUserLogin` 复用注入的 storage | 已完成 |
| `CheckDeviceConnection` 复用注入的 keychain | 已完成 |
| session 自动恢复与自动清理链路 | 已完成 |
| README、SPI 配置、测试补齐 | 已完成 |

## 14. 下一步实施项

| 优先级 | 项目 |
| --- | --- |
| P1 | 继续收敛 `ApiBase` 层的 public surface |
| P1 | 将 `ApiCore`、`Transport`、`Storage`、`Interceptors` 目录进一步显式拆分 |
| P2 | 补充 flow 层集成测试 |
| P2 | 补充真实接入示例工程或示例代码片段 |
| P3 | 评估是否引入 DocC 文档输出 |
