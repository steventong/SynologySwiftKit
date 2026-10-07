import Foundation

/// 一个客户端的会话写操作串行化；新操作取消旧操作并等待其清理完成。
/// 同步外部状态替换会使旧操作的提交和回滚一起失效。
final class SessionOperationCoordinator: @unchecked Sendable {
    private struct Context: Sendable {
        let owner: SessionOperationCoordinator
        let id: UUID
        let externalRevision: UInt64
        let requestRevision: UInt64
    }
    private struct RequestContext: Sendable {
        let owner: SessionOperationCoordinator
        let revision: UInt64
    }
    @TaskLocal private static var context: Context?
    @TaskLocal private static var requestContext: RequestContext?

    private let lock = NSRecursiveLock()
    private let stateDidSettle: () -> Void

    init(stateDidSettle: @escaping () -> Void = {}) { self.stateDidSettle = stateDidSettle }
    private var latestID: UUID?
    private var runningID: UUID?
    private var externalRevision: UInt64 = 0
    private var requestRevision: UInt64 = 0
    private var cancelActive: (() -> Void)?
    private var tail: Task<Void, Never>?
    private var completions: [UUID: Task<Void, Never>] = [:]

    func start<Value>(invalidatesRequests: Bool = true, _ work: @escaping () async throws -> Value) -> Task<Value, Error> {
        locked {
            let predecessor = tail
            let id = UUID()
            let revision = externalRevision
            latestID = id
            if invalidatesRequests { requestRevision &+= 1 }
            cancelActive?()
            let requestRevision = requestRevision
            let task = Task<Value, Error> { [self] in
                defer {
                    locked {
                        completions[id] = nil
                        if runningID == id { stateDidSettle(); runningID = nil }
                        if latestID == id { latestID = nil; cancelActive = nil }
                    }
                }
                if let predecessor { await predecessor.value }
                try Task.checkCancellation()
                let context = try locked { () throws -> Context in
                    guard latestID == id, externalRevision == revision else { throw CancellationError() }
                    runningID = id
                    return Context(owner: self, id: id, externalRevision: revision, requestRevision: requestRevision)
                }
                return try await Self.$context.withValue(context) {
                    let result = try await work()
                    try checkCurrent()
                    return result
                }
            }
            cancelActive = { task.cancel() }
            let completion = Task { _ = try? await task.value }
            completions[id] = completion
            tail = completion
            return task
        }
    }

    func perform<Value>(_ work: @escaping () async throws -> Value) async throws -> Value {
        if Self.context?.owner === self {
            try checkCurrent()
            let value = try await work()
            try checkCurrent()
            return value
        }
        let task = start(work)
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    func commit<Value>(_ mutation: () throws -> Value) throws -> Value {
        try locked {
            try checkCurrent()
            return try mutation()
        }
    }

    /// 发布完整事务的最终状态，必须早于完成事件或返回值向调用者交付。
    func commitState<Value>(_ mutation: () throws -> Value) throws -> Value {
        try commit {
            let value = try mutation()
            stateDidSettle()
            return value
        }
    }

    func rollback(_ mutation: () -> Void) {
        locked {
            guard let context = Self.context, context.owner === self,
                  runningID == context.id, externalRevision == context.externalRevision else { return }
            mutation()
        }
    }

    func replaceState(_ mutation: () -> Void) {
        locked {
            externalRevision &+= 1
            requestRevision &+= 1
            latestID = nil
            cancelActive?()
            cancelActive = nil
            mutation()
            stateDidSettle()
        }
    }

    /// 返回当前请求世代，普通请求等待会话写入结束，流程内部请求不等待自己。
    func requestStamp() async throws -> UInt64 {
        if Self.context?.owner === self {
            try checkCurrent()
            return locked { requestRevision }
        }
        while true {
            let pending = locked { latestID == nil ? nil : tail }
            if let pending { await pending.value }
            try Task.checkCancellation()
            if let revision = locked({ latestID == nil ? requestRevision : nil }) { return revision }
        }
    }

    func validateRequest(_ revision: UInt64) throws {
        try Task.checkCancellation()
        try locked {
            guard revision == requestRevision else { throw CancellationError() }
        }
    }

    func withRequest<Value>(stamp: UInt64, _ work: () async throws -> Value) async throws -> Value {
        try await Self.$requestContext.withValue(RequestContext(owner: self, revision: stamp)) {
            try validateRequest(stamp)
            return try await work()
        }
    }

    func mutateForCurrentRequest(_ mutation: () -> Void) {
        locked {
            guard let request = Self.requestContext, request.owner === self,
                  request.revision == requestRevision, !Task.isCancelled else { return }
            mutation()
            if runningID == nil { stateDidSettle() }
        }
    }

    /// 后台发现等待恢复结束后独立运行，不占用会话写入队列；真正换地址时再调用 perform。
    func performAfterCurrent<Value>(_ work: @escaping () async throws -> Value) async throws -> Value {
        guard let context = Self.context, context.owner === self else { throw CancellationError() }
        let predecessor = locked { completions[context.id] }
        if let predecessor { await predecessor.value }
        return try await Self.$context.withValue(nil) {
            try Task.checkCancellation()
            try locked {
                guard requestRevision == context.requestRevision else { throw CancellationError() }
            }
            return try await work()
        }
    }

    private func checkCurrent() throws {
        try Task.checkCancellation()
        try locked {
            guard let context = Self.context, context.owner === self,
                  context.id == latestID, context.id == runningID,
                  context.externalRevision == externalRevision else { throw CancellationError() }
        }
    }

    private func locked<Value>(_ work: () throws -> Value) rethrows -> Value {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }
}
