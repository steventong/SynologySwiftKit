# 优化建议说明

本文对前面提到的优化点做更详细的解释，并列出可能涉及的文件，方便你按优先级推进。

## 架构层优化

### 1) 统一网络栈（单一入口） ✅ 已完成
**为什么重要**  
目前同时存在 `HTTPClient` 与 `ApiClient` 两套网络逻辑，日志、错误处理、超时策略不一致，维护成本高且行为不一致。  

**建议调整**  
统一到一套传输层。建议保留 `ApiClient` 为统一入口，并将 `HTTPClient` 作为内部传输实现或直接下线。`QuickConnectApi` 也走同一套网络栈，避免“同项目两种标准”。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/HTTPClient.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/ApiBase/ApiClient.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/QuickConnect/QuickConnectApi.swift`

### 2) 打通拦截器链（RequestInterceptor） ✅ 已完成
**为什么重要**  
拦截器协议已经定义，但 `ApiClient` 没有执行链路，导致日志/鉴权/重试等横切逻辑无法集中管理。

**建议调整**  
在 `ApiClient.sendHttpRequest` 中：
- 请求前按顺序执行 `adapt`
- 响应后按逆序执行 `process`  
这样可在不改主流程的情况下拓展功能。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/NetworkInterceptor.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/LoggerInterceptor.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/AuthInterceptor.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/ApiBase/ApiClient.swift`

### 3) 配置注入要真正生效 ✅ 已完成
**为什么重要**  
`SynologyConfig` 已定义但没有贯穿所有服务，导致配置表面存在但无法影响行为。

**建议调整**  
让 `SynologyClient` 负责统一装配，将配置传给 `ApiClient`、`ApiInfoApi`、`QuickConnectApi` 等模块，避免硬编码超时和缓存 TTL。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/SynologyConfig.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/SynologyClient.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/ApiInfo/ApiInfoApi.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/QuickConnect/QuickConnectApi.swift`

### 4) 强化 API 层与业务流的边界
**为什么重要**  
`BizFlow` 理应只依赖 API 层接口，避免直接依赖存储和配置细节。当前 `AuthApi`/`QuickConnectApi` 直接使用 `UserDefaults`，耦合强、不利测试。

**建议调整**  
引入并统一使用 `KeyValueStorage` 注入，避免直接访问 `UserDefaults.standard`。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/KeyValueStorage.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/Auth/AuthApi.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/QuickConnect/QuickConnectApi.swift`

## 实现层优化

### 5) 统一错误模型 ✅ 已完成
**为什么重要**  
文档里出现 `SynologyError.network(...)`，但枚举中并不存在该分支。容易导致理解偏差与代码不一致。

**建议调整**  
引入结构化 `NetworkError`，并在 `ApiClient`/`HTTPClient` 等统一使用，删除旧的 `http(String)` 风格。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/SynologyError.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/ApiBase/ApiClient.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/HTTPClient.swift`

### 6) ApiInfo 缓存 TTL 应可配置
**为什么重要**  
`ApiInfoApi` 仍硬编码 TTL，导致 `SynologyConfig.apiInfoCacheValidity` 实际无效。

**建议调整**  
从配置中读取 TTL，配置驱动缓存策略。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/ApiInfo/ApiInfoApi.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/SynologyConfig.swift`

### 7) 移除对 UserDefaults.standard 的直依赖
**为什么重要**  
直接用 `UserDefaults.standard` 会降低可测试性，也让存储策略无法切换。

**建议调整**  
统一走 `KeyValueStorage`，并在 `SynologyClient` 注入。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/KeyValueStorage.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/Auth/AuthApi.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/QuickConnect/QuickConnectApi.swift`

### 8) 日志脱敏与开关控制
**为什么重要**  
日志可能包含 Cookie、SID、密码、OTP 等敏感字段，生产环境存在严重风险。

**建议调整**  
增加字段脱敏规则（`Cookie`、`Authorization`、`passwd`、`otp_code`、`_sid` 等），并通过 `SynologyConfig.enableNetworkLogging` 统一控制。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/NetworkLogger.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/Logger.swift`

### 9) SSL 信任逻辑增强
**为什么重要**  
当前 `SSLTrustDelegate` 只校验 host 就直接信任证书，绕过了系统信任评估。

**建议调整**  
使用 `SecTrustEvaluateWithError` 校验证书链，且建议限制在 Debug/开发环境使用自签证书信任。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/URLSessionFactory.swift`

### 10) 减少 `Any` 参数
**为什么重要**  
`ApiEndpoint.parameters` 使用 `[String: Any]`，丢失编译期类型检查，容易出现运行时错误。

**建议调整**  
考虑使用 `Encodable` 请求模型或 `URLQueryItem` 形式统一序列化。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/ApiBase/ApiEndpoint.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/ApiBase/ApiParametersBuilder.swift`

### 11) 去掉 `@unchecked Sendable` 风险
**为什么重要**  
`SynologyClient` 被标记为 `@unchecked Sendable`，但内部包含可变状态（例如 `ApiClient` 的拦截器列表），存在并发安全隐患。

**建议调整**  
将拦截器改为初始化时固定或加锁/actor 保护，确保线程安全。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/SynologyClient.swift`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/ApiBase/ApiClient.swift`

### 12) 移除 `.DS_Store`
**为什么重要**  
`.DS_Store` 是系统文件，进入仓库会污染版本历史。

**建议调整**  
加入 `.gitignore` 并清理。

**涉及文件**  
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/.DS_Store`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/.DS_Store`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/Common/.DS_Store`
- `/Users/tongwanglin/Workspace/XcodeProjects/SynologySwiftKit/Sources/SynologySwiftKit/DiskStationApi/.DS_Store`
