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
    /// Whether a thought in this state still decays and can be offered for review.
    var isLive: Bool {
        switch self {
        case .inbox, .active, .snoozed: true
        case .archived, .done: false
        }
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
