import Foundation

protocol ConnectionManaging {
    func recoverConnection() async -> ConnectionRecoveryDecision
    func refreshQuickConnectEndpoint() async -> SynologyConnection?
    func listCandidates() async throws -> [SynologyConnectionCandidate]
    func switchConnection(to connection: SynologyConnection) async throws -> SynologyConnection
}
