import Foundation

protocol ConnectionRecoveryProviding {
    func recoverConnection() async -> ConnectionRecoveryDecision
    func optimizeQuickConnectEndpoint() async -> SynologyConnection?
}
