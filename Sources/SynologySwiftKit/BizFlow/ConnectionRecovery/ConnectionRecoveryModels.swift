import Foundation

// MARK: - Connection Recovery Models

public enum ConnectionRecoveryFollowUp: Sendable, Equatable {
    case optimizeQuickConnectEndpoint
}

public enum ConnectionRecoveryStatus: Sendable, Equatable {
    case connected
    case requiresRelogin
    case disconnected
}

public struct ConnectionRecoveryDecision: Sendable, Equatable {
    public let status: ConnectionRecoveryStatus
    public let followUp: ConnectionRecoveryFollowUp?

    public init(status: ConnectionRecoveryStatus, followUp: ConnectionRecoveryFollowUp?) {
        self.status = status
        self.followUp = followUp
    }
}
