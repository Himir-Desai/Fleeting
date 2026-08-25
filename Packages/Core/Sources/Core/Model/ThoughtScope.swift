import Foundation

/// Which part of the collection a query is asking about.
public enum ThoughtScope: String, CaseIterable, Sendable {
    /// Thoughts still in play: inbox, active, or snoozed.
    case live
    /// Thoughts that have expired or been set aside. Recoverable, never deleted.
    case archived
    /// Everything, regardless of lifecycle position.
    case all

    /// Whether a state belongs in this scope.
    /// - Parameter state: The lifecycle position to test.
    /// - Returns: `true` if a thought in that state should appear.
    public func contains(_ state: ThoughtState) -> Bool {
        switch self {
        case .live: state.isLive
        case .archived: !state.isLive
        case .all: true
        }
    }
}
