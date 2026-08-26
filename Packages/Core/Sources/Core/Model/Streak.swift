import Foundation

/// A run of consecutive days on which a habit was marked done.
///
/// Counted in elapsed time rather than calendar days, deliberately: a calendar streak depends on
/// the device's time zone and would break when travelling, and it cannot be tested without
/// injecting a calendar.
public struct Streak: Equatable, Sendable {
    /// How many consecutive days the habit has been kept.
    public private(set) var count: Int

    /// When the habit was last marked done, or `nil` if it never has been.
    public private(set) var lastMarkedAt: Date?

    /// Creates a streak.
    /// - Parameters:
    ///   - count: Days kept so far. Defaults to none.
    ///   - lastMarkedAt: When it was last marked. Defaults to never.
    public init(count: Int = 0, lastMarkedAt: Date? = nil) {
        self.count = max(count, 0)
        self.lastMarkedAt = lastMarkedAt
    }

    /// Whether the habit has been kept at least once.
    public var hasStarted: Bool {
        count >= 1
    }

    /// Records the habit as done.
    ///
    /// Marking twice within a day changes nothing. Marking within two days continues the run.
    /// Anything longer starts a new one.
    /// - Parameter date: When the habit was marked done.
    public mutating func mark(at date: Date) {
        defer { lastMarkedAt = date }

        guard let lastMarkedAt else {
            count = 1
            return
        }

        let gap = date.timeIntervalSince(lastMarkedAt)
        switch gap {
        case ..<0: return
        case ..<TimeInterval.day: return
        case ..<(2 * TimeInterval.day): count += 1
        default: count = 1
        }
    }
}
