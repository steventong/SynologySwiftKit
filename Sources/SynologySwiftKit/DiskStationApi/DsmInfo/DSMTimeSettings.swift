import Foundation

public enum DSMTimeZoneError: Error, Sendable {
    case invalidResponse
}

/// Numeric settings read from the NAS, without interpreting DSM's zone names.
public struct DSMTimeZoneInfo: Sendable {
    /// Current effective offset, including any daylight saving, for NAS calendar dates.
    /// A snapshot of the NAS clock, not a rule for converting future instants.
    public let currentTimeZone: TimeZone
    /// The configured dropdown's GMT prefix, e.g. GMT+08:00.
    /// This is a display label, not the effective offset at a future expiry date.
    public let displayPrefix: String
}

struct DSMTimeZoneList: Decodable {
    struct Zone: Decodable {
        let value: String
        let offset: Int
    }
    let zonedata: [Zone]
}

struct DSMTimeSettings: Decodable {
    let timezone: String
    let date: String
    let hour: Int
    let minute: Int
    let second: Int
    let timestamp: Double

    func resolvedTimeZone(from list: DSMTimeZoneList) throws -> DSMTimeZoneInfo {
        // Both IDs come from this NAS. Treat them as opaque keys: no local
        // city lookup, translation, alias table, or IANA-name recognition.
        let matches = list.zonedata.filter { $0.value == timezone }
        guard !timezone.isEmpty, matches.count == 1, let zone = matches.first,
              (-18 * 3600...18 * 3600).contains(zone.offset), zone.offset % 60 == 0 else {
            throw DSMTimeZoneError.invalidResponse
        }
        let magnitude = abs(zone.offset)
        let prefix = String(format: "GMT%@%02d:%02d", zone.offset < 0 ? "-" : "+", magnitude / 3600, magnitude % 3600 / 60)

        // listzone's offset is the dropdown label, which may exclude DST.
        // Derive the current calendar offset from one server clock snapshot
        // so relative dates still use the NAS's actual day near midnight.
        let parts = date.replacingOccurrences(of: "-", with: "/").split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second),
              timestamp.isFinite else { throw DSMTimeZoneError.invalidResponse }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let localAsUTC = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: localAsUTC) == components else {
            throw DSMTimeZoneError.invalidResponse
        }
        let difference = localAsUTC.timeIntervalSince1970 - timestamp
        let offset = (difference / 60).rounded() * 60
        // Allow a one-second boundary between fields produced by DSM.
        guard abs(difference - offset) <= 1, abs(offset) <= 18 * 3600,
              let currentTimeZone = TimeZone(secondsFromGMT: Int(offset)) else {
            throw DSMTimeZoneError.invalidResponse
        }
        return DSMTimeZoneInfo(currentTimeZone: currentTimeZone, displayPrefix: prefix)
    }
}
