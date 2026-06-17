import Foundation

/// App-wide JSON coders.
///
/// PostgREST returns both full timestamps (`timestamptz`) and bare dates
/// (`date`). The default decoder only understands one format, so we install a
/// custom strategy that tries every shape Postgres emits.
enum AppJSON {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parse(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrecognized date: \(raw)"
            )
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: Date parsing

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let postgresTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return f
    }()

    static func parse(_ raw: String) -> Date? {
        if let d = isoFractional.date(from: raw) { return d }
        if let d = isoPlain.date(from: raw) { return d }
        if let d = postgresTimestamp.date(from: raw) { return d }
        if let d = dateOnly.date(from: raw) { return d }
        return nil
    }
}

/// Formats a `Date` as a Postgres `date` literal (yyyy-MM-dd, UTC).
extension Date {
    var pgDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
}
