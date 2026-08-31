import Foundation

/// Where a thought sits in its lifecycle.
///
/// States that end a thought's active life carry the date they were entered, so history is
/// preserved without a separate audit trail.
public enum ThoughtState: Equatable, Sendable {
    /// Captured but not yet triaged.
    case inbox
    /// Triaged and in play.
    case active
    /// Deliberately set aside until the given date.
    case snoozed(until: Date)
    /// Expired by decay or archived by hand. Recoverable; never deleted.
    case archived(at: Date)
    /// Completed.
    case done(at: Date)
}

public extension ThoughtState {
    /// Whether a thought in this state still has an active life — that is, it has neither expired
    /// nor been completed.
    ///
    /// Answers "does this still exist for the user", not "does this want attention now": a
    /// snoozed thought is live but deliberately silent. Ask ``isAwake(at:)`` before showing a
    /// thought or acting on it. This is date-free on purpose, because it is the rule the store
    /// writes into a column, and a stored column cannot know when a snooze lapses.
    var isLive: Bool {
        switch self {
        case .inbox, .active, .snoozed: true
        case .archived, .done: false
        }
    }

    /// Whether a thought in this state is asking for attention at a given instant.
    ///
    /// Live and not inside a running snooze. Every surface that shows thoughts to a person — the
    /// list, the widget, the review, the nudges — filters on this rather than on ``isLive``,
    /// because setting something aside has to mean something or snoozing is just a slower way of
    /// being nagged.
    /// - Parameter date: The instant to judge at.
    /// - Returns: `true` when the thought is in play right now.
    func isAwake(at date: Date) -> Bool {
        guard isLive else { return false }
        if case let .snoozed(until) = self {
            return date >= until
        }
        return true
    }

    /// The date this state was entered, for states that record one.
    var enteredAt: Date? {
        switch self {
        case .inbox, .active: nil
        case let .snoozed(until): until
        case let .archived(date): date
        case let .done(date): date
        }
    }
}
