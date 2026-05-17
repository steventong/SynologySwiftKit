import Foundation

protocol ConnectionRecoveryProviding {
    func recoverConnection() async -> ConnectionRecoveryDecision
}
