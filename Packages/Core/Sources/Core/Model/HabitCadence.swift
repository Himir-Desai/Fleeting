import Foundation

/// How often a habit is meant to be kept.
///
/// The unit a streak is counted in, and the window a mark satisfies. Until this existed every
/// habit was implicitly daily, so a weekly one sat on the home screen six days out of seven
/// asking to be done again (ADR-0048).
public enum HabitCadence: String, CaseIterable, Codable, Sendable {
    /// Once a day.
    case daily
    /// Once every few days.
    case everyFewDays
    /// Once a week.
    case weekly
    /// Once a fortnight.
    case fortnightly
    /// Once a month.
    case monthly

    /// The cadence a habit has when nothing has said otherwise.
    ///
    /// Daily, because that is what most habits are and because it is the safest wrong answer: a
    /// habit shown too often is a nuisance, but one shown too rarely silently stops being a habit.
    public static let `default` = HabitCadence.daily

    /// How long one period lasts, in seconds.
    ///
    /// Elapsed time rather than calendar arithmetic, matching ``Streak``: a calendar period
    /// depends on the device's time zone and breaks when travelling (ADR-0048).
    public var period: TimeInterval {
        switch self {
        case .daily: .day
        case .everyFewDays: 3 * .day
        case .weekly: 7 * .day
        case .fortnightly: 14 * .day
        case .monthly: 30 * .day
        }
    }

    /// How long a run may lapse before it is broken, in seconds.
    ///
    /// Twice the period, mirroring the daily rule a streak has always used: miss one and the run
    /// survives, miss two and it starts again.
    public var grace: TimeInterval {
        2 * period
    }

    /// What the cadence is called in the interface.
    public var label: String {
        switch self {
        case .daily: "Daily"
        case .everyFewDays: "Every few days"
        case .weekly: "Weekly"
        case .fortnightly: "Fortnightly"
        case .monthly: "Monthly"
        }
    }

    /// What one kept period is called, for a streak count.
    ///
    /// A weekly habit kept four times is a four week streak, not a four day one.
    /// - Parameter count: How many periods have been kept.
    /// - Returns: The unit, pluralised to match the count.
    public func streakUnit(count: Int) -> String {
        let singular = switch self {
        case .daily: "day"
        case .everyFewDays, .weekly: "week"
        case .fortnightly: "fortnight"
        case .monthly: "month"
        }
        return count == 1 ? singular : singular + "s"
    }
}
