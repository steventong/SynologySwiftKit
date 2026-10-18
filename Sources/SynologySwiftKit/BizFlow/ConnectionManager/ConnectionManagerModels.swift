import Foundation

// MARK: - Connection Recovery Models

/// QuickConnect 地址刷新结果，区分地址更新、会话失效和连接不可用。
enum QuickConnectEndpointRefreshOutcome: Sendable {
    case updated(SynologyConnection)
    case requiresRelogin
    case unavailable
}

public enum ConnectionRecoveryStatus: Sendable, Equatable {
    case connected
    case requiresRelogin
    case disconnected
}

public struct ConnectionRecoveryDecision: Sendable, Equatable {
    public let status: ConnectionRecoveryStatus

    public init(status: ConnectionRecoveryStatus) {
        self.status = status
    }

    public static let connected = ConnectionRecoveryDecision(status: .connected)
    public static let requiresRelogin = ConnectionRecoveryDecision(status: .requiresRelogin)
    public static let disconnected = ConnectionRecoveryDecision(status: .disconnected)
}
