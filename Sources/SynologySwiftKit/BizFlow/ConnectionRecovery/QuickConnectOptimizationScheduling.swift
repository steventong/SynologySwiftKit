import Foundation

protocol QuickConnectOptimizationScheduling {
    func run(
        operation: @escaping @Sendable () async -> SynologyConnection?
    ) async -> SynologyConnection?

    func schedule(
        operation: @escaping @Sendable () async -> SynologyConnection?
    ) async
}

struct NoOpQuickConnectOptimizationScheduler: QuickConnectOptimizationScheduling {
    func run(
        operation: @escaping @Sendable () async -> SynologyConnection?
    ) async -> SynologyConnection? {
        await operation()
    }

    func schedule(
        operation: @escaping @Sendable () async -> SynologyConnection?
    ) async {}
}
