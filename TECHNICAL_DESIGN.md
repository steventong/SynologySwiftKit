# SynologySwiftKit 技术设计

## 目标

`SynologySwiftKit` 是一个用于在 Apple 平台上接入 Synology DSM (Audio Station) 的 Swift Package。

本文档用于说明这个 Package 的技术架构、预期的模块边界，以及为了让它更适合开源使用和长期演进而采用的设计原则。

设计目标如下：

- 提供一个小而清晰、容易理解的公共入口
- 让 transport、storage 和副作用实现可替换
- 让核心流程在不依赖真实网络或真实设备的情况下也能测试
- 将 Synology 协议细节与更高层的业务流程隔离开
- 允许 Package 持续演进，同时尽量减少对使用方造成不必要的 breaking change

## 设计原则

### 1. Public API 应该小于实现本身

Package 内部可以有很多构件，但外部使用者只应该接触少量稳定入口。

推荐的 Public APIs 包括：

- `SynologyClient`
- 通过 client 暴露出来的功能模块，例如 `auth`、`audioStation`、`fileStation`、`quickConnect`
- 领域模型和稳定的错误类型
- 明确的扩展点，例如 transport、storage、interceptor

除非存在强烈的外部使用场景，否则实现细节类型应保持为内部可见。

### 2. 依赖倒置优先于具体实现耦合

核心流程应该依赖协议和能力边界，而不是直接依赖某个具体网络库或持久化实现。

这样做的收益包括：

- 更容易测试
- 更容易迁移
- 更容易维护
- 未来更容易替换第三方库

### 3. 编排逻辑与协议细节分离

底层 DSM 请求构建与响应解析应停留在基础设施层。
更高层的登录、连接解析等流程应该组合这些能力，而不是重复实现协议细节。

### 4. 配置与运行时状态必须显式表达

Package 需要明确区分：

- 静态配置
- 可变的运行时 session 状态
- 持久化相关状态
- 网络副作用

这样可以让行为更可预测，也更容易推理。

## 架构概览

整个 Package 可以按四层来理解。

### 第一层：公共入口层

主要职责：

- 为外部消费者提供稳定入口
- 负责依赖装配
- 暴露功能模块与业务流程

核心类型：

- `SynologyClient`

预期职责：

- 持有 Package 级配置
- 装配默认 transport、storage 和 interceptor
- 暴露稳定的功能 API
- 暴露稳定的业务流程

这一层不应泄漏请求构建细节或解析器内部实现。

### 第二层：功能与流程层

主要职责：

- 暴露对用户有意义的能力
- 编排多步骤业务流程

功能 API：

- `AuthApi`
- `QuickConnectApi`
- `AudioStationApi`
- `FileStationApi`
- `DsmInfoApi`
- `EncryptionApi`

业务流程：

- `SynologyUserLogin`
- `CheckDeviceConnection`
- `QueryAllSongs`

功能 API 应该封装 Synology 服务边界。
业务流程应该负责把多个 API 组合成端到端流程。

### 第三层：领域层

主要职责：

- 定义不依赖 transport 细节的稳定领域概念

示例：

- `SynologyError`
- `SynologyConfig`
- `ConnectionType`
- `ServerType`
- `AuthResult`
- `Song`、`Album`、`Playlist`、`AudioStationInfo` 等面向使用者的模型

领域层应该在不阅读网络层实现的前提下，也能被理解和复用。

### 第四层：基础设施层

主要职责：

- 实现网络、持久化、日志，以及 Synology 请求协议处理

示例：

- `ApiClient`
- `ApiEndpoint`
- `HTTPTransporting`
- `SwiftHttpClientTransport`
- `KeyValueStorage`
- `KeyChainStorage`
- interceptor
- 响应解码与内部错误映射

这一层内部可以复杂，但不应该主导外部可见 API。

## 依赖方向

依赖流向应该保持单向：

`公共入口层` -> `功能与流程层` -> `领域层`

以及

`功能与流程层` -> `基础设施层`，通过协议或较窄的内部契约进行依赖

重要约束：

- 上层可以依赖下层
- 下层不应反向依赖高层流程逻辑
- 基础设施层不应拥有业务策略

## 运行时装配核心

`SynologyClient` 充当组合根（composition root）。

初始化时它应该：

- 接收 Package 级配置
- 接收敏感与非敏感状态的 storage 实现
- 接收 transport 实现
- 创建 API client
- 在合适时注册默认 interceptor
- 构建各个功能 API
- 基于这些 API 构建更高层的业务流程

这样既能给外部使用者提供一个稳定入口，也能保留内部模块化结构。

## 主要架构构件

### SynologyClient

角色：

- Package 的组合根
- 对外的公共 facade

应暴露：

- 稳定的功能 API
- 稳定的流程 API
- 当它们确实属于外部行为时，可适度暴露 session 辅助能力

不应暴露：

- 内部解析细节
- 低层原始响应结构，除非确实存在强使用场景

### ApiClient

角色：

- 低层 DSM 请求执行引擎

职责：

- 将 endpoint 解析成 URL 与请求对象
- 应用 interceptor
- 通过 `HTTPTransporting` 发送请求
- 解码响应数据
- 将 transport 或协议失败映射成 Package 级错误

在可能的情况下，它应尽量保持为内部实现细节。

### 功能 API

角色：

- 表达某一块边界明确的 Synology 服务能力

示例：

- `AuthApi` 负责登录、登出和凭据相关请求
- `QuickConnectApi` 负责 QuickConnect 地址解析
- `AudioStationApi` 负责音乐相关能力分组

功能 API 应当保持聚焦，避免不断堆积不相关的流程编排逻辑。

### 业务流程

角色：

- 将多个能力拼装成端到端用户流程

示例：

- 登录流程
- 连接校验流程
- 全量歌曲查询流程

这些流程是放置步骤编排、重试、进度流、状态迁移逻辑的合适位置。

### Storage 抽象

当前设计将存储分为两类：

- 用于非敏感缓存与轻量持久状态的 key-value storage
- 用于凭据与 session 敏感值的 keychain storage

设计要求：

- 外部使用者必须能够替换 storage 实现
- 业务流程必须复用注入进来的 storage，而不是内部偷偷 new 默认实例

### Transport 抽象

`HTTPTransporting` 是 Package 对外发起网络请求的边界。

设计要求：

- 第三方 HTTP client 的选择应被收敛在 transport 边界后面
- Package 其他层不应直接依赖 `SwiftHttpClient`

这样可以避免整个 Package 在架构上被某一个网络库绑死。

## 状态模型

Package 里的运行时状态应当是显式的。

### 静态配置

由 `SynologyConfig` 表达。

示例：

- 超时设置
- 日志行为
- 默认缓存策略

这类状态在可能的情况下，应在初始化后保持不可变。

### 运行时 Session 状态

示例：

- 当前连接
- 当前 session 的 SID 与 DID
- 推导得到的可达 endpoint

这类状态属于当前运行中的 client，也可以同步镜像到持久化存储中。

### 持久化状态

示例：

- 已保存凭据
- 最近一次可用连接
- 缓存的 API info
- 缓存的 Audio Station info

持久化不应该隐藏在随意的模块里。
持久化数据的来源必须保持清晰且可替换。

## 并发模型

Package 已经使用 Swift Concurrency，后续应继续保持一致。

当前建议：

- 只有在确实存在可变共享状态或串行访问需求时才使用 `actor`
- 对需要跨并发边界传递的公共领域类型，标记为 `Sendable`
- 除非必要，避免混用零散的线程安全策略
- 通过 `async` 函数或 `AsyncStream` 保持异步流程表达清晰

并发正确性应当是 API 设计的一部分，而不是实现完成后的补丁。

## 错误模型

对外错误表面应尽量统一到 `SynologyError`。

内部层可以解码或理解原始协议错误，但在暴露给外部使用者之前，应先完成归一化处理。

推荐的错误分类：

- 网络 / transport 错误
- 认证错误
- session 失效
- API / 业务错误

这样做的重要性在于：

- 外部使用者可以写出稳定可预期的错误处理逻辑
- 内部 transport 或解析实现变化时，不会轻易引发公共 API 抖动

## 日志与可观测性

日志属于运行时架构的一部分，不应只是调试补充。

要求：

- 日志应能集中配置
- Package 日志应能安全关闭
- 日志实现不应通过功能 API 泄漏出去
- 日志应帮助追踪请求生命周期和流程层决策

未来可以继续增强的点：

- 为复杂多步骤操作增加结构化 request id 或 flow correlation metadata

## 测试策略

架构层面应支持三种测试范围。

### 单元测试

覆盖目标：

- endpoint 构建
- 请求拦截
- 错误映射
- storage 行为
- 纯工具与辅助函数

要求：

- 不依赖真实网络
- 不依赖真实 DSM 环境

### 流程测试

覆盖目标：

- 登录流程行为
- 连接解析行为
- session 恢复与失效行为

要求：

- 使用 mock API client
- 使用可预测的 storage
- 显式覆盖成功与失败场景

### 集成测试

覆盖目标：

- 针对真实或受控 Synology 环境的端到端行为

这类测试有价值，但不应该成为每个贡献者验证核心正确性的前置条件。

## Public API 设计准则

判断某个类型是否应该公开时，可以用以下标准：

### 在这些情况下应公开：

- 外部使用者必须自己实现它
- 外部使用者必须注入它
- 外部使用者必须捕获或理解它
- 它表达的是稳定的领域概念

### 在这些情况下应保持内部：

- 它只是为了支持请求装配
- 它只是为了支持解码内部结构
- 它只是为了适配第三方依赖
- 它的修改不应被视为 breaking change

通常应优先保持内部的类型示例：

- 原始 Synology 响应包装结构
- 低层错误映射器
- 内部常量
- 仅用于辅助 transport 编码的类型

## 推荐演进方向

后续架构演进应持续朝这些方向推进：

- 更收敛的公共 API 表面
- 更清晰的功能 API 与基础设施边界
- 更强的协议驱动编排边界
- 更完善的流程与 session 行为自动化测试
- 更完整的 DSM 与 Audio Station 能力文档

## 非目标

这个 Package 的目标不是：

- 一个通用 HTTP 框架
- 一个完整的应用架构框架
- 一个 UI 框架

它应始终聚焦在 Synology 接入及其相关业务流程上。

## 建议中的仓库结构

一个更易维护的长期结构可以是：

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

这不需要一次性完成，但它是一个合理的长期架构目标。

## 架构评审检查清单

在继续扩展 Package 前，可以先检查：

- 新功能应放进现有功能模块，还是应拆出新模块？
- 新类型真的属于公共契约的一部分吗？
- 这个行为能否在不接入真实 DSM 的情况下完成测试？
- 这个流程依赖的是协议，还是直接依赖具体基础设施实现？
- 这次改动是否仍然把请求协议细节控制在 public API 边界之下？
- 外部使用者是否能在不阅读内部实现文件的前提下，理解这个新 API 应该怎么用？

## 总结

`SynologySwiftKit` 的理想架构形态是：

- 一个清晰的公共入口
- 聚焦的功能模块
- 明确的业务流程
- 稳定的领域层
- 可替换的基础设施
- 经过控制且有意收敛的 public API

这是最有利于长期开源采用、安全重构和外部贡献的架构形态。
