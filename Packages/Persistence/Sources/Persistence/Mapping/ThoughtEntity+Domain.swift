import Core
import Foundation

extension ThoughtEntity {
    /// Creates the stored form of a domain thought.
    /// - Parameter thought: The thought to store.
    convenience init(_ thought: Thought) {
        self.init(id: thought.id, capturedAt: thought.capturedAt)
        overwrite(with: thought)
    }

    /// The domain thought this row represents.
    var domain: Thought {
        Thought(
            id: id,
            body: body,
            capturedAt: capturedAt,
            kind: ThoughtKind(rawValue: kindRaw) ?? .unsorted,
            state: StoredState.state(code: stateCode),
            title: title,
            lastActedAt: lastActedAt,
            kindSource: KindSource(rawValue: kindSourceRaw) ?? .unclassified,
            dueAt: dueAt,
            streak: StoredStreak.streak(code: streakCode),
            sharpening: StoredSharpening.decode(sharpeningJSON),
            snoozeCount: snoozeCount
        )
    }

    /// Overwrites this row with the contents of a domain thought, preserving identity.
    ///
    /// Writes version 1's lifecycle columns alongside the combined ones. They are never read,
    /// only kept current, so an older build installed over this one still works (ADR-0019).
    /// - Parameter thought: The thought whose contents should replace this row's.
    func overwrite(with thought: Thought) {
        body = thought.body
        title = thought.title
        kindRaw = thought.kind.rawValue
        lastActedAt = thought.lastActedAt
        kindSourceRaw = thought.kindSource.rawValue
        dueAt = thought.dueAt
        sharpeningJSON = StoredSharpening.encode(thought.sharpening)
        snoozeCount = thought.snoozeCount

        stateCode = StoredState.code(for: thought.state)
        streakCode = StoredStreak.code(for: thought.streak)
        isLive = ThoughtScope.live.contains(thought.state)

        let legacy = StoredState.components(of: thought.state)
        stateRaw = legacy.raw
        stateDate = legacy.date
        streakCount = thought.streak?.count ?? 0
        streakLastMarkedAt = thought.streak?.lastMarkedAt
    }
}
