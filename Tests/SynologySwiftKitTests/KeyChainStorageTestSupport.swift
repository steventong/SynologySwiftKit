import Foundation
import Security
@testable import SynologySwiftKit

func makeKeyChainStorage(service: String) -> KeyChainStorage {
    KeyChainStorage(service: service, backend: InMemoryKeychainBackend())
}

private final class InMemoryKeychainBackend: KeychainBackend, @unchecked Sendable {
    private var values: [String: Data] = [:]
    private let lock = NSLock()

    func save(_ data: Data, service: String, account: String) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        values[key(service: service, account: account)] = data
        return errSecSuccess
    }

    func read(service: String, account: String) -> (status: OSStatus, data: Data?) {
        lock.lock()
        defer { lock.unlock() }

        guard let data = values[key(service: service, account: account)] else {
            return (errSecItemNotFound, nil)
        }
        return (errSecSuccess, data)
    }

    func delete(service: String, account: String) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: key(service: service, account: account))
        return errSecSuccess
    }

    private func key(service: String, account: String) -> String {
        "\(service)\u{0}\(account)"
    }
}
