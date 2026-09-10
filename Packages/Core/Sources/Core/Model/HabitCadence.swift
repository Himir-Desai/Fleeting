import Foundation

/// How often a habit is meant to be kept: a number, and the unit it is counted in.
///
/// A quantity rather than a fixed menu, so "every 3 days" and "every 2 months" are sayable
/// without the app having to have anticipated them (ADR-0050). Reuses ``ExpirationUnit``, which
/// already spells days, weeks and months for hand-set lifetimes: one vocabulary for durations.
public struct HabitCadence: Equatable, Hashable, Codable, Sendable {
    /// How many ``unit`` between one keeping and the next. Always at least one.
    public let count: Int

    /// The unit the ``count`` is measured in.
    public let unit: ExpirationUnit

    /// Creates a cadence.
    ///
    /// A count below one is raised to one: "every zero days" is not a rhythm, and clamping here
    /// means no caller has to defend against it.
    /// - Parameters:
    ///   - count: How many units between keepings.
    ///   - unit: The unit to count in.
    public init(count: Int, unit: ExpirationUnit) {
        self.count = max(count, 1)
        self.unit = unit
    }

    /// The cadence a habit has when nothing has said otherwise.
    ///
    /// Daily, because that is what most habits are and because it is the safest wrong answer: a
    /// habit shown too often is a nuisance, but one shown too rarely silently stops being a habit.
    public static let `default` = HabitCadence(count: 1, unit: .days)

    /// Every day.
    public static let daily = HabitCadence(count: 1, unit: .days)

    /// Every week.
    public static let weekly = HabitCadence(count: 1, unit: .weeks)

    /// Every month.
    public static let monthly = HabitCadence(count: 1, unit: .months)

    /// How long one period lasts, in seconds.
    ///
    /// Elapsed time rather than calendar arithmetic, matching ``Streak``: a calendar period
    /// depends on the device's time zone and breaks when travelling (ADR-0048).
    public var period: TimeInterval {
        TimeInterval(count) * unit.seconds
    }

    /// How long a run may lapse before it is broken, in seconds.
    ///
    /// Twice the period, mirroring the daily rule a streak has always used: miss one and the run
    /// survives, miss two and it starts again.
    public var grace: TimeInterval {
        2 * period
    }

    /// What the cadence is called in the interface: "Daily", "Every 3 days", "Weekly".
    ///
    /// The common rhythms get their ordinary English names, because "every 1 days" is not how
    /// anyone says it.
    public var label: String {
        guard count > 1 else {
            switch unit {
            case .days: return "Daily"
            case .weeks: return "Weekly"
            case .months: return "Monthly"
            }
        }
        return "Every \(count) \(unit.label.lowercased())"
    }

    /// What one kept period is called, for a streak count.
    ///
    /// A weekly habit kept four times is a four week streak, not a four day one. A habit kept
    /// every three days is counted in times, because "4 3-days" is not a unit anyone would read.
    /// - Parameter count: How many periods have been kept.
    /// - Returns: The unit, pluralised to match the count.
    public func streakUnit(count keptCount: Int) -> String {
        let singular = if count > 1 {
            "time"
        } else {
            switch unit {
            case .days: "day"
            case .weeks: "week"
            case .months: "month"
            }
        }
        return keptCount == 1 ? singular : singular + "s"
    }
}

// MARK: - Codable

/// Encoded as `"3 days"`, so a stored cadence is readable by eye and survives a unit being added.
public extension HabitCadence {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = HabitCadence(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "unreadable cadence: \(raw)"
                )
            )
        }
        self = parsed
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Storage spelling

public extension HabitCadence {
    /// The stored spelling: the count and the unit, separated by a space.
    ///
    /// A string rather than two columns so persistence keeps one optional attribute, and so a
    /// cadence remains one value everywhere it travels.
    var rawValue: String {
        "\(count) \(unit.rawValue)"
    }

    /// Reads a stored cadence.
    ///
    /// Returns `nil` for anything unreadable rather than throwing, so a corrupt value costs a
    /// habit its rhythm — which falls back to the default — never the habit itself.
    /// - Parameter rawValue: The stored spelling.
    init?(rawValue: String) {
        let parts = rawValue.split(separator: " ")
        guard parts.count == 2,
              let count = Int(parts[0]),
              let unit = ExpirationUnit(rawValue: String(parts[1]))
        else { return nil }
        self.init(count: count, unit: unit)
    }
}
