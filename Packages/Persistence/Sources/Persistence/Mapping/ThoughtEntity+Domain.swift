import Core
import Foundation

/// The storable spelling of ``Core/ThoughtState``.
///
/// A separate type on purpose: the domain enum may gain cases or change shape without forcing
/// a store migration, and this is the one place the two vocabularies meet.
enum StoredState: String, CaseIterable {
    case inbox, active, snoozed, archived, done

    /// The raw values whose domain states are still in play.
    ///
    /// Derived from the domain rather than duplicated, so a new lifecycle case cannot silently
    /// fall on the wrong side of the live/archived split.
    static var liveRawValues: [String] {
        allCases
            .filter { ThoughtScope.live.contains(state(raw: $0.rawValue, date: .distantFuture)) }
            .map(\.rawValue)
    }

    /// Flattens a domain state into a raw case and its associated date, if it has one.
    static func components(of state: ThoughtState) -> (raw: String, date: Date?) {
        switch state {
        case .inbox: (inbox.rawValue, nil)
        case .active: (active.rawValue, nil)
        case let .snoozed(until): (snoozed.rawValue, until)
        case let .archived(at): (archived.rawValue, at)
        case let .done(at): (done.rawValue, at)
        }
    }

    /// Rebuilds a domain state from stored components.
    /// - Returns: The domain state, or `.inbox` if the stored data is unreadable — a corrupt
    ///   row must never lose the thought, only its lifecycle position.
    static func state(raw: String, date: Date?) -> ThoughtState {
        switch StoredState(rawValue: raw) {
        case .inbox, .none: .inbox
        case .active: .active
        case .snoozed: date.map { .snoozed(until: $0) } ?? .inbox
        case .archived: date.map { .archived(at: $0) } ?? .inbox
        case .done: date.map { .done(at: $0) } ?? .inbox
        }
    }
}

extension ThoughtEntity {
    /// Creates the stored form of a domain thought.
    convenience init(_ thought: Thought) {
        let state = StoredState.components(of: thought.state)
        self.init(
            id: thought.id,
            body: thought.body,
            title: thought.title,
            kindRaw: thought.kind.rawValue,
            stateRaw: state.raw,
            stateDate: state.date,
            capturedAt: thought.capturedAt,
            lastActedAt: thought.lastActedAt,
            kindSourceRaw: thought.kindSource.rawValue,
            dueAt: thought.dueAt,
            streakCount: thought.streak?.count ?? 0,
            streakLastMarkedAt: thought.streak?.lastMarkedAt,
            sharpeningJSON: StoredSharpening.encode(thought.sharpening)
        )
    }

    /// The domain thought this row represents.
    var domain: Thought {
        Thought(
            id: id,
            body: body,
            capturedAt: capturedAt,
            kind: ThoughtKind(rawValue: kindRaw) ?? .unsorted,
            state: StoredState.state(raw: stateRaw, date: stateDate),
            title: title,
            lastActedAt: lastActedAt,
            kindSource: KindSource(rawValue: kindSourceRaw) ?? .unclassified,
            dueAt: dueAt,
            streak: storedStreak,
            sharpening: StoredSharpening.decode(sharpeningJSON)
        )
    }

    /// The habit streak this row represents, or `nil` if the habit was never marked.
    private var storedStreak: Streak? {
        guard streakLastMarkedAt != nil || streakCount > 0 else { return nil }
        return Streak(count: streakCount, lastMarkedAt: streakLastMarkedAt)
    }

    /// Overwrites this row with the contents of a domain thought, preserving identity.
    /// - Parameter thought: The thought whose contents should replace this row's.
    func overwrite(with thought: Thought) {
        let state = StoredState.components(of: thought.state)
        body = thought.body
        title = thought.title
        kindRaw = thought.kind.rawValue
        stateRaw = state.raw
        stateDate = state.date
        lastActedAt = thought.lastActedAt
        kindSourceRaw = thought.kindSource.rawValue
        dueAt = thought.dueAt
        streakCount = thought.streak?.count ?? 0
        streakLastMarkedAt = thought.streak?.lastMarkedAt
        sharpeningJSON = StoredSharpening.encode(thought.sharpening)
    }
}
