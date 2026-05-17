import Foundation

actor QuickConnectOptimizationCoordinator: QuickConnectOptimizationScheduling {
    private var activeTask: Task<SynologyConnection?, Never>?

    func run(
        operation: @escaping @Sendable () async -> SynologyConnection?
    ) async -> SynologyConnection? {
        if let activeTask {
            return await activeTask.value
        }

        let task = Task {
            await operation()
        }
        activeTask = task

        let result = await task.value
        activeTask = nil
        return result
    }

    func schedule(
        operation: @escaping @Sendable () async -> SynologyConnection?
    ) {
        guard activeTask == nil else {
            return
        }

        let task = Task {
            await operation()
        }
        activeTask = task

        Task {
            _ = await task.value
            clear()
        }
    }

    private func clear() {
        activeTask = nil
    }
}
