import Foundation

public struct SynologyConnection: Sendable {
    public let type: ConnectionType
    public let url: String

    public init(type: ConnectionType, url: String) {
        self.type = type
        self.url = url
    }
}

public struct SynologySession: Sendable {
    public let sid: String
    public let did: String?

    public init(sid: String, did: String?) {
        self.sid = sid
        self.did = did
    }
}

public final class SessionClient {
    private let connectionProvider: () -> SynologyConnection?
    private let sessionProvider: () -> SynologySession?
    private let sessionUpdater: (String, String?) -> Void
    private let sessionClearer: () -> Void

    init(connectionProvider: @escaping () -> SynologyConnection?,
         sessionProvider: @escaping () -> SynologySession?,
         sessionUpdater: @escaping (String, String?) -> Void,
         sessionClearer: @escaping () -> Void) {
        self.connectionProvider = connectionProvider
        self.sessionProvider = sessionProvider
        self.sessionUpdater = sessionUpdater
        self.sessionClearer = sessionClearer
    }

    public var connection: SynologyConnection? {
        connectionProvider()
    }

    public var current: SynologySession? {
        sessionProvider()
    }

    public var hasValidSession: Bool {
        current != nil
    }

    public func update(sid: String, did: String?) {
        sessionUpdater(sid, did)
    }

    public func clear() {
        sessionClearer()
    }
}
