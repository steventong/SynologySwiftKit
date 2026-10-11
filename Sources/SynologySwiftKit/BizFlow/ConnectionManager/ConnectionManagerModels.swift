import Foundation

// MARK: - Connection Recovery Models

/// 内部地址优化保留会话失效证据，不能把服务器明确失效与网络不可用都折叠为 nil。
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
