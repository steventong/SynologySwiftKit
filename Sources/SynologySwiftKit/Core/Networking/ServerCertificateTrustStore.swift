import Foundation

final class ServerCertificateTrustStore: @unchecked Sendable {
    private let storage: KeyValueStorage
    private let lock = NSLock()

    init(storage: KeyValueStorage) {
        self.storage = storage
    }

    func approvedFingerprint(forHost host: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return fingerprints()[normalizedHost(host)]
    }

    func approve(_ certificate: SynologyServerCertificate) {
        lock.lock()
        defer { lock.unlock() }

        var stored = fingerprints()
        stored[normalizedHost(certificate.host)] = certificate.sha256Fingerprint
        storage.setCodable(stored, forKey: KeyValueStorageKeys.APPROVED_SERVER_CERTIFICATES.keyName)
    }

    private func fingerprints() -> [String: String] {
        storage.codable(forKey: KeyValueStorageKeys.APPROVED_SERVER_CERTIFICATES.keyName) ?? [:]
    }

    private func normalizedHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
