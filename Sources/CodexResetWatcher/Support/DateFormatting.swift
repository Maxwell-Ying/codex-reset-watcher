import Foundation

@MainActor
enum DateFormatting {
    private static let fractionalParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return fractionalParser.date(from: value) ?? standardParser.date(from: value)
    }

    static func full(_ value: String?) -> String {
        guard let date = parse(value) else {
            return "-"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func compact(_ value: String?) -> String {
        guard let date = parse(value) else {
            return "-"
        }

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func checked(_ date: Date?) -> String {
        guard let date else {
            return "Not checked yet"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return "Last checked \(formatter.string(from: date))"
    }
}
