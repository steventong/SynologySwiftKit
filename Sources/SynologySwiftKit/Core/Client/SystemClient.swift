import Foundation

public final class ConnectionClient {
    public let quickConnect: QuickConnectClient
    let ping: PingPong

    init(quickConnect: QuickConnectClient, ping: PingPong) {
        self.quickConnect = quickConnect
        self.ping = ping
    }
}

public final class SystemClient {
    public let dsmInfo: DSMInfoClient
    public let encryption: EncryptionClient
    public let connection: ConnectionClient

    init(dsmInfo: DSMInfoClient, encryption: EncryptionClient, connection: ConnectionClient) {
        self.dsmInfo = dsmInfo
        self.encryption = encryption
        self.connection = connection
    }
}
