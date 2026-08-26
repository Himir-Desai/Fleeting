import Core
import Foundation

/// The storable spelling of a ``Core/Streak``.
///
/// The count and the date it belongs to are encoded into a single string, for the same reason
/// the lifecycle state is: iCloud merges records column by column, and a count from one device
/// paired with a date from another describes a run that never happened (ADR-0019).
enum StoredStreak {
    /// Separates the count from the date it was last marked.
    private static let separator: Character = "|"

    /// Encodes a streak.
    /// - Parameter streak: The streak to store, or `nil` if the habit was never marked.
    /// - Returns: A single value, or `nil` for no streak.
    static func code(for streak: Streak?) -> String? {
        guard let streak else { return nil }
        return code(count: streak.count, lastMarkedAt: streak.lastMarkedAt)
    }

    /// Encodes a streak that is already split into a count and a date.
    ///
    /// Used by the version 1 migration and by the columns kept for rollback.
    /// - Parameters:
    ///   - count: How many days the habit has been kept.
    ///   - lastMarkedAt: When it was last marked, if ever.
    /// - Returns: A single value, or `nil` if there is no streak to record.
    static func code(count: Int, lastMarkedAt: Date?) -> String? {
        guard lastMarkedAt != nil || count > 0 else { return nil }
        guard let lastMarkedAt else { return "\(count)" }
        return "\(count)\(separator)\(lastMarkedAt.timeIntervalSinceReferenceDate)"
    }

    /// Rebuilds a streak from an encoded value.
    /// - Parameter code: The stored value, or `nil` for no streak.
    /// - Returns: The streak, or `nil` if there is none or the value is unreadable.
    static func streak(code: String?) -> Streak? {
        guard let code else { return nil }
        let parts = code.split(separator: separator, maxSplits: 1)
        guard let count = parts.first.flatMap({ Int($0) }) else { return nil }
        let lastMarkedAt = parts.count > 1
            ? Double(parts[1]).map(Date.init(timeIntervalSinceReferenceDate:))
            : nil
        guard lastMarkedAt != nil || count > 0 else { return nil }
        return Streak(count: count, lastMarkedAt: lastMarkedAt)
    }
}
