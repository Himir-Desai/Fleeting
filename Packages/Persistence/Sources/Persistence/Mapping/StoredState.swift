import Core
import Foundation

/// The storable spelling of ``Core/ThoughtState``.
///
/// A separate type on purpose: the domain enum may gain cases or change shape without forcing a
/// store migration, and this is the one place the two vocabularies meet.
///
/// A state and the date belonging to it are encoded into a single string, because iCloud merges
/// records column by column and two columns can arrive from two different devices (ADR-0019).
enum StoredState: String, CaseIterable {
    case inbox, active, snoozed, archived, done

    /// Separates the lifecycle position from its date.
    private static let separator: Character = "|"

    /// Encodes a domain state.
    /// - Parameter state: The lifecycle position to store.
    /// - Returns: A single value carrying both the position and its date.
    static func code(for state: ThoughtState) -> String {
        let parts = components(of: state)
        return code(raw: parts.raw, date: parts.date)
    }

    /// Encodes a lifecycle position that is already split into a raw case and a date.
    ///
    /// Used by the version 1 migration and by the columns kept for rollback.
    /// - Parameters:
    ///   - raw: The stored case name.
    ///   - date: The date belonging to that case, if it has one.
    /// - Returns: A single value carrying both.
    static func code(raw: String, date: Date?) -> String {
        guard let date else { return raw }
        return "\(raw)\(separator)\(date.timeIntervalSinceReferenceDate)"
    }

    /// Splits a domain state into a raw case and its associated date, if it has one.
    static func components(of state: ThoughtState) -> (raw: String, date: Date?) {
        switch state {
        case .inbox: (inbox.rawValue, nil)
        case .active: (active.rawValue, nil)
        case let .snoozed(until): (snoozed.rawValue, until)
        case let .archived(at): (archived.rawValue, at)
        case let .done(at): (done.rawValue, at)
        }
    }

    /// Rebuilds a domain state from an encoded value.
    /// - Parameter code: The stored value.
    /// - Returns: The domain state, or `.inbox` if the value is unreadable — an unparseable row
    ///   must never lose the thought, only its lifecycle position.
    static func state(code: String) -> ThoughtState {
        let parts = code.split(separator: separator, maxSplits: 1)
        let raw = parts.first.map(String.init) ?? ""
        let date = parts.count > 1
            ? Double(parts[1]).map(Date.init(timeIntervalSinceReferenceDate:))
            : nil

        switch StoredState(rawValue: raw) {
        case .inbox, .none: return .inbox
        case .active: return .active
        case .snoozed: return date.map { .snoozed(until: $0) } ?? .inbox
        case .archived: return date.map { .archived(at: $0) } ?? .inbox
        case .done: return date.map { .done(at: $0) } ?? .inbox
        }
    }

    /// Whether an encoded state is still in play.
    ///
    /// Derived from the domain rather than duplicated, so a new lifecycle case cannot silently
    /// fall on the wrong side of the live/archived split.
    /// - Parameter code: The stored value.
    /// - Returns: `true` if a thought in that state belongs in the live scope.
    static func isLive(code: String) -> Bool {
        ThoughtScope.live.contains(state(code: code))
    }
}
