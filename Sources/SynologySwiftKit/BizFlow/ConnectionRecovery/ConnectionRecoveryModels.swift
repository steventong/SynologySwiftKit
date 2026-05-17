import Foundation

// MARK: - Connection Recovery Models

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
