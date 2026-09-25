import Foundation

/// A calendar date that stays on the same day when the device changes time zones.
public struct PlanDay: RawRepresentable, Codable, Hashable, Comparable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Creates a day from an instant in the user's time zone.
    public init(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = (parts.year ?? 1) * 10000 + (parts.month ?? 1) * 100 + (parts.day ?? 1)
    }

    /// The beginning of this calendar day in a time zone.
    public func date(timeZone: TimeZone = .autoupdatingCurrent) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: DateComponents(
            year: rawValue / 10000, month: rawValue / 100 % 100, day: rawValue % 100
        )), PlanDay(date, timeZone: timeZone) == self else { return nil }
        return date
    }

    public static func < (lhs: PlanDay, rhs: PlanDay) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
