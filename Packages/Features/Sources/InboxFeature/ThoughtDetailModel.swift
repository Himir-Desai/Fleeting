import Core
import Foundation
import Observation

/// State and actions for the opened thought — the hub where a thought is edited, retyped, kept,
/// snoozed, archived or deleted.
///
/// Writes straight to the repository and announces each change, so the list behind it refreshes
/// itself; it does not depend on the inbox's own state.
@MainActor
@Observable
public final class ThoughtDetailModel {
    /// The thought as it currently stands, updated after each action.
    public private(set) var thought: Thought

    /// The editable raw text. Committed on demand, never on every keystroke.
    public var draft: String

    /// Whether a custom lifetime is applied instead of the kind's normal decay rate.
    public var usesCustomExpiration: Bool

    /// How many ``expirationUnit`` the custom lifetime lasts.
    public var expirationCount: Int

    /// The unit the ``expirationCount`` is measured in.
    public var expirationUnit: ExpirationUnit

    private let repository: any ThoughtRepository
    private let changes: ThoughtChangeNotifier
    private let clock: any WallClock

    /// Creates the detail's state.
    /// - Parameters:
    ///   - thought: The thought being opened.
    ///   - repository: Where the change is written back.
    ///   - changes: Told after each change so the list refreshes.
    ///   - clock: Time source for deliberate actions.
    public init(
        thought: Thought,
        repository: any ThoughtRepository,
        changes: ThoughtChangeNotifier = ThoughtChangeNotifier(),
        clock: any WallClock
    ) {
        self.thought = thought
        self.repository = repository
        self.changes = changes
        self.clock = clock
        draft = thought.body
        if let lifetime = thought.customLifetime {
            usesCustomExpiration = true
            let decomposed = Self.decompose(lifetime)
            expirationCount = decomposed.count
            expirationUnit = decomposed.unit
        } else {
            usesCustomExpiration = false
            expirationCount = 1
            expirationUnit = .months
        }
    }

    /// Whether the draft differs from what is stored and is worth committing.
    public var canSaveText: Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != thought.body
    }

    /// Commits the edited text, if it changed. Counts as deliberate action.
    public func saveText() async {
        guard canSaveText else { return }
        var revised = thought
        revised.revise(body: draft.trimmingCharacters(in: .whitespacesAndNewlines), at: clock.now)
        await persist(revised)
    }

    /// Sets the thought's kind by hand, which classification will then never overwrite.
    /// - Parameter kind: The chosen kind.
    public func chooseKind(_ kind: ThoughtKind) async {
        guard kind != thought.kind else { return }
        var corrected = thought
        corrected.confirmKind(kind, at: clock.now)
        await persist(corrected)
    }

    /// Applies the current expiry wheels, or clears the override when custom expiry is off.
    public func applyExpiry() async {
        var updated = thought
        updated.setCustomLifetime(customLifetime)
        await persist(updated)
    }

    /// Marks a to-do complete, taking it out of the live list.
    public func complete() async {
        var completed = thought
        completed.complete(at: clock.now)
        await persist(completed)
    }

    /// Records a habit as kept, extending its streak and restoring its freshness.
    public func markHabitKept() async {
        var kept = thought
        kept.markHabitKept(at: clock.now)
        await persist(kept)
    }

    /// Sets the thought aside for a number of days, held at full freshness until then.
    /// - Parameter days: How long to snooze for.
    public func snooze(forDays days: Double) async {
        var snoozed = thought
        snoozed.snooze(until: clock.now.addingTimeInterval(days * .day), at: clock.now)
        await persist(snoozed)
    }

    /// Archives the thought by hand.
    public func archive() async {
        var archived = thought
        archived.archive(at: clock.now)
        await persist(archived)
    }

    /// Permanently deletes the thought. The only path here that destroys anything.
    public func delete() async {
        try? await repository.delete(id: thought.id)
        changes.notify()
    }

    /// The chosen lifetime in seconds, or `nil` to follow the kind's decay rate.
    private var customLifetime: TimeInterval? {
        guard usesCustomExpiration else { return nil }
        return TimeInterval(max(expirationCount, 1)) * expirationUnit.seconds
    }

    /// Writes a changed thought back, updates the local copy, and announces the change.
    /// - Parameter thought: The updated thought.
    private func persist(_ thought: Thought) async {
        try? await repository.update(thought)
        self.thought = thought
        changes.notify()
    }

    /// Splits a lifetime in seconds back into a whole count and the largest even unit, so the
    /// wheels open on the value that was set.
    /// - Parameter seconds: The stored lifetime.
    /// - Returns: The count and unit to show.
    private static func decompose(_ seconds: TimeInterval) -> (count: Int, unit: ExpirationUnit) {
        let days = Int((seconds / .day).rounded())
        if days >= 30, days % 30 == 0 {
            return (days / 30, .months)
        }
        if days >= 7, days % 7 == 0 {
            return (days / 7, .weeks)
        }
        return (max(days, 1), .days)
    }
}
