import Foundation

protocol ConnectionRouteManaging {
    func listCandidates() async throws -> [SynologyConnectionCandidate]
    func switchConnection(to connection: SynologyConnection) async throws -> SynologyConnection
}
