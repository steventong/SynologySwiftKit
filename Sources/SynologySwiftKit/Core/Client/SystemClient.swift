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
    public let device: DSMInfoClient
    public let security: EncryptionClient
    public let network: ConnectionClient

    init(device: DSMInfoClient, security: EncryptionClient, network: ConnectionClient) {
        self.device = device
        self.security = security
        self.network = network
    }
}
