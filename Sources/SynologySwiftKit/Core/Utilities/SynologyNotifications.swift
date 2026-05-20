import Foundation

public extension Notification.Name {
    /// Posted after the current connection is reachable and the ambient DSM session is validated.
    static let synologyOnlineSessionValidated = Notification.Name("synologyOnlineSessionValidated")

    /// Posted after QuickConnect optimization refreshes the current endpoint.
    static let synologyQuickConnectEndpointOptimized = Notification.Name("synologyQuickConnectEndpointOptimized")
}

public struct SynologyOnlineSessionValidatedEvent: Sendable, Equatable {
    public let connection: SynologyConnection
    public let serverType: ServerType

    public init(connection: SynologyConnection, serverType: ServerType) {
        self.connection = connection
        self.serverType = serverType
    }

    public init?(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let connection = SynologyNotificationUserInfoParser.connection(from: userInfo),
              let serverType = SynologyNotificationUserInfoParser.serverType(from: userInfo)
        else {
            return nil
        }

        self.init(connection: connection, serverType: serverType)
    }

    func toUserInfo() -> [String: Any] {
        [
            SynologyNotificationUserInfoKey.connectionURL: connection.url,
            SynologyNotificationUserInfoKey.connectionType: connection.type.rawValue,
            SynologyNotificationUserInfoKey.serverType: serverType.rawValue,
        ]
    }
}

public struct SynologyQuickConnectEndpointOptimizedEvent: Sendable, Equatable {
    public let updatedConnection: SynologyConnection
    public let previousConnection: SynologyConnection?

    public init(updatedConnection: SynologyConnection, previousConnection: SynologyConnection?) {
        self.updatedConnection = updatedConnection
        self.previousConnection = previousConnection
    }

    public init?(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let updatedConnection = SynologyNotificationUserInfoParser.connection(from: userInfo)
        else {
            return nil
        }

        self.init(
            updatedConnection: updatedConnection,
            previousConnection: SynologyNotificationUserInfoParser.previousConnection(from: userInfo)
        )
    }

    func toUserInfo() -> [String: Any] {
        var userInfo: [String: Any] = [
            SynologyNotificationUserInfoKey.connectionURL: updatedConnection.url,
            SynologyNotificationUserInfoKey.connectionType: updatedConnection.type.rawValue,
            SynologyNotificationUserInfoKey.serverType: ServerType.quickConnectId.rawValue,
        ]

        if let previousConnection {
            userInfo[SynologyNotificationUserInfoKey.previousConnectionURL] = previousConnection.url
            userInfo[SynologyNotificationUserInfoKey.previousConnectionType] = previousConnection.type.rawValue
        }

        return userInfo
    }
}

private enum SynologyNotificationUserInfoKey {
    static let connectionURL = "connectionURL"
    static let connectionType = "connectionType"
    static let previousConnectionURL = "previousConnectionURL"
    static let previousConnectionType = "previousConnectionType"
    static let serverType = "serverType"
}

private enum SynologyNotificationUserInfoParser {
    static func connection(from userInfo: [AnyHashable: Any]) -> SynologyConnection? {
        guard let connectionURL = userInfo[SynologyNotificationUserInfoKey.connectionURL] as? String,
              let connectionTypeRawValue = userInfo[SynologyNotificationUserInfoKey.connectionType] as? String,
              let connectionType = ConnectionType(rawValue: connectionTypeRawValue)
        else {
            return nil
        }

        return SynologyConnection(type: connectionType, url: connectionURL)
    }

    static func previousConnection(from userInfo: [AnyHashable: Any]) -> SynologyConnection? {
        guard let connectionURL = userInfo[SynologyNotificationUserInfoKey.previousConnectionURL] as? String,
              let connectionTypeRawValue = userInfo[SynologyNotificationUserInfoKey.previousConnectionType] as? String,
              let connectionType = ConnectionType(rawValue: connectionTypeRawValue)
        else {
            return nil
        }

        return SynologyConnection(type: connectionType, url: connectionURL)
    }

    static func serverType(from userInfo: [AnyHashable: Any]) -> ServerType? {
        guard let serverTypeRawValue = userInfo[SynologyNotificationUserInfoKey.serverType] as? String else {
            return nil
        }
        return ServerType(rawValue: serverTypeRawValue)
    }
}
