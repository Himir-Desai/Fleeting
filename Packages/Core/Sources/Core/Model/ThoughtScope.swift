import Foundation

/// Which part of the collection a query is asking about.
///
/// A storage-shaped question, not a presentation one. ``live`` means "not archived and not
/// completed", which includes thoughts inside a running snooze — the store cannot know when a
/// snooze lapses, because that depends on the current date and the scope is compiled into a
/// predicate over a stored column. Callers showing thoughts to a person must filter the result
/// with ``Thought/isAwake(at:)``.
public enum ThoughtScope: String, CaseIterable, Sendable {
    /// Thoughts still in play: inbox, active, or snoozed. Includes running snoozes.
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
