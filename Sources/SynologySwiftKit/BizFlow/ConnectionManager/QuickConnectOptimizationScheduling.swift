import Foundation

protocol QuickConnectOptimizationScheduling {
    func run(
        operation: @escaping @Sendable () async -> QuickConnectEndpointRefreshOutcome
    ) async -> QuickConnectEndpointRefreshOutcome

    func schedule(
        operation: @escaping @Sendable () async -> QuickConnectEndpointRefreshOutcome
    ) async
}

struct NoOpQuickConnectOptimizationScheduler: QuickConnectOptimizationScheduling {
    func run(
        operation: @escaping @Sendable () async -> QuickConnectEndpointRefreshOutcome
    ) async -> QuickConnectEndpointRefreshOutcome {
        await operation()
    }

    func schedule(
        operation: @escaping @Sendable () async -> QuickConnectEndpointRefreshOutcome
    ) async {}
}
