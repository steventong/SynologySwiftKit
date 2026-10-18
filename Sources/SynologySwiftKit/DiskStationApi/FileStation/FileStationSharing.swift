import Foundation

/// A File Station public sharing link. Dates are calendar dates in the NAS time zone;
/// "0" means no date restriction. Status is reported by DSM (for example "valid").
public struct FileStationSharingLink: Decodable, Identifiable, Sendable {
    public let id: String
    public let path: String
    public let url: String
    public let name: String?
    public let status: String?
    public let dateExpired: String?
    public let dateAvailable: String?
    public let hasPassword: Bool?

    public init(id: String, path: String, url: String, name: String? = nil, status: String? = nil,
                dateExpired: String? = nil, dateAvailable: String? = nil, hasPassword: Bool? = nil) {
        self.id = id
        self.path = path
        self.url = url
        self.name = name
        self.status = status
        self.dateExpired = dateExpired
        self.dateAvailable = dateAvailable
        self.hasPassword = hasPassword
    }

    enum CodingKeys: String, CodingKey {
        case id, path, url, name, status
        case dateExpired = "date_expired", dateAvailable = "date_available", hasPassword = "has_password"
    }
}

public struct FileStationSharingPage: Decodable, Sendable {
    public let total: Int
    public let offset: Int
    public let links: [FileStationSharingLink]
}

extension FileStationClient {
    /// Lists the signed-in user's links. A limit of zero requests all links.
    /// Refresh status before presenting links that may have expired or been moved.
    public func listSharingLinks(offset: Int = 0, limit: Int = 0,
                                 refreshStatus: Bool = false) async throws -> FileStationSharingPage {
        try await apiClient.request(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.Sharing"), method: "list", version: 3
        ) {
            ("offset", max(0, offset))
            ("limit", max(0, limit))
            ("force_clean", refreshStatus)
        })
    }

    public func sharingLink(id: String) async throws -> FileStationSharingLink {
        let quotedID = try ApiParameterValue.jsonEncoded(id)
        return try await apiClient.request(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.Sharing"), method: "getinfo", version: 3
        ) { ("id", quotedID) })
    }

    /// Creates one link. expirationDate is YYYY-MM-DD in the NAS time zone, or nil
    /// for a permanent link. Does not retry: after a lost response, query existing
    /// links before attempting another creation. The returned URL is supplied by DSM.
    public func createSharingLink(path: String, expirationDate: String? = nil,
                                  password: String? = nil) async throws -> FileStationSharingLink {
        if let expirationDate { try validateSharingDate(expirationDate) }
        try validateSharingPassword(password)
        let quotedPath = try ApiParameterValue.jsonEncoded(path)
        let quotedDate = try ApiParameterValue.jsonEncoded(expirationDate ?? "0")
        let quotedPassword = try password.map { try ApiParameterValue.jsonEncoded($0) }
        let result: SharingCreation = try await apiClient.request(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.Sharing"), method: "create", version: 3, httpMethod: .post
        ) {
            ("path", quotedPath)
            ("date_expired", quotedDate)
            if let quotedPassword { ("password", quotedPassword) }
        })
        guard let item = result.links.first, result.links.count == 1 else {
            throw SynologyError.api(code: -1, message: "Sharing result missing; query links before retrying")
        }
        guard item.error == 0 else {
            throw SynologyError.api(code: item.error, message: "Could not create sharing link")
        }
        guard let id = item.id, !id.isEmpty, let url = item.url, !url.isEmpty, item.path == path else {
            throw SynologyError.api(code: -1, message: "Sharing result incomplete; query links before retrying")
        }
        return FileStationSharingLink(id: id, path: path, url: url, name: nil, status: "valid",
                                      dateExpired: expirationDate ?? "0", dateAvailable: "0",
                                      hasPassword: password.map { !$0.isEmpty } ?? false)
    }

    /// Updates an existing link without changing its URL. Nil leaves a field unchanged;
    /// expirationDate "0" means permanent, and an empty password removes protection.
    /// Dates are YYYY-MM-DD in the NAS time zone. A failed request is not retried.
    public func updateSharingLink(id: String, expirationDate: String? = nil,
                                  password: String? = nil) async throws {
        if let expirationDate, expirationDate != "0" { try validateSharingDate(expirationDate) }
        try validateSharingPassword(password)
        let quotedID = try ApiParameterValue.jsonEncoded(id)
        let quotedDate = try expirationDate.map { try ApiParameterValue.jsonEncoded($0) }
        let quotedPassword = try password.map { try ApiParameterValue.jsonEncoded($0) }
        let _: EmptyData = try await apiClient.request(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.Sharing"), method: "edit", version: 3, httpMethod: .post
        ) {
            ("id", quotedID)
            if let quotedDate { ("date_expired", quotedDate) }
            if let quotedPassword { ("password", quotedPassword) }
        })
    }

    private func validateSharingDate(_ value: String) throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            throw SynologyError.api(code: 400, message: "Expiration date must be YYYY-MM-DD")
        }
    }

    private func validateSharingPassword(_ password: String?) throws {
        guard password.map({ $0.count <= 16 }) ?? true else {
            throw SynologyError.api(code: 400, message: "Sharing password must not exceed 16 characters")
        }
    }

    /// Revokes this link only; the underlying file/folder is not deleted.
    public func deleteSharingLink(id: String) async throws {
        let quotedID = try ApiParameterValue.jsonEncoded(id)
        let _: EmptyData = try await apiClient.request(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.Sharing"), method: "delete", version: 3, httpMethod: .post
        ) { ("id", quotedID) })
    }

    struct SharingCreation: Decodable {
        let links: [Item]
        struct Item: Decodable {
            let error: Int
            let id: String?
            let path: String?
            let url: String?
        }
    }
}
