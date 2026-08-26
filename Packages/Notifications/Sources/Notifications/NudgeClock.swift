import Foundation

/// Works out when the next daily or weekly nudge should land.
///
/// Takes a `Calendar` so tests can pin a time zone rather than depending on the machine's.
public struct NudgeClock: Sendable {
    let calendar: Calendar

    /// Creates a nudge clock.
    /// - Parameter calendar: The calendar to compute against. Defaults to the current one.
    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// The next time today or tomorrow that the given hour comes round.
    /// - Parameters:
    ///   - hour: Hour of day, 0–23.
    ///   - now: The instant to search forward from.
    /// - Returns: The next matching instant, always strictly in the future.
    public func nextDaily(hour: Int, after now: Date) -> Date? {
        calendar.nextDate(
            after: now,
            matching: DateComponents(hour: hour, minute: 0),
            matchingPolicy: .nextTime
        )
    }

    /// The next time the given weekday and hour come round.
    /// - Parameters:
    ///   - weekday: Weekday, 1 for Sunday through 7 for Saturday.
    ///   - hour: Hour of day, 0–23.
    ///   - now: The instant to search forward from.
    /// - Returns: The next matching instant, always strictly in the future.
    public func nextWeekly(weekday: Int, hour: Int, after now: Date) -> Date? {
        calendar.nextDate(
            after: now,
            matching: DateComponents(hour: hour, minute: 0, weekday: weekday),
            matchingPolicy: .nextTime
        )
    }
}
