import Core
import Foundation
import Observation

/// State and rules for the habits shown on the home screen beside the capture field.
///
/// A habit is the one kind of thought that needs touching every day, so it is the one kind that
/// earns a place on the screen a cold launch lands on (ADR-0047). Reads the same store and calls
/// the same model operations the inbox does, so a mark made here and a mark made in the list are
/// the same event.
@MainActor
@Observable
public final class DailyHabitsModel {
    /// Live habits, the ones still needing today's mark first.
    public private(set) var habits: [Thought] = []

    /// Whether the first load has finished, so an empty list can be told apart from an unread one.
    public private(set) var hasLoaded = false

    /// How many marks this screen has recorded. Drives the mark haptic.
    public private(set) var markedCount = 0

    private let repository: any ThoughtRepository
    private let changes: ThoughtChangeNotifier
    private let clock: any WallClock

    /// Creates the home screen's habit strip state.
    /// - Parameters:
    ///   - repository: Where habits are read from and written back to.
    ///   - changes: Told when a habit is marked, so the list and any nudges keep up.
    ///   - clock: Time source used to stamp a mark and to decide what is still due today.
    public init(
        repository: any ThoughtRepository,
        changes: ThoughtChangeNotifier = ThoughtChangeNotifier(),
        clock: any WallClock
    ) {
        self.repository = repository
        self.changes = changes
        self.clock = clock
    }

    /// Whether there is anything to show. Used to keep the home screen blank when there is not.
    public var hasHabits: Bool {
        !habits.isEmpty
    }

    /// Reloads the live habits, awake ones only, with anything still due today listed first.
    ///
    /// Failures are swallowed on purpose: this strip sits on the capture screen, and a read that
    /// fails must never put an error in front of the field (ADR-0008).
    public func load() async {
        let now = clock.now
        let live = await (try? repository.thoughts(in: .live)) ?? []
        habits = live
            .filter { $0.kind == .habit && $0.isAwake(at: now) }
            .sorted { left, right in
                let leftDue = !isKeptToday(left)
                let rightDue = !isKeptToday(right)
                if leftDue != rightDue {
                    return leftDue
                }
                return left.capturedAt < right.capturedAt
            }
        hasLoaded = true
    }

    /// Whether a habit has already been marked within the last day, so today's mark is done.
    /// - Parameter thought: The habit to check.
    /// - Returns: `true` when marking again would change nothing.
    public func isKeptToday(_ thought: Thought) -> Bool {
        guard let lastMarkedAt = thought.streak?.lastMarkedAt else { return false }
        return clock.now.timeIntervalSince(lastMarkedAt) < .day
    }

    /// How long a habit's run is, in days.
    /// - Parameter thought: The habit to read.
    /// - Returns: The streak count, or zero if it has never been kept.
    public func streakCount(of thought: Thought) -> Int {
        thought.streak?.count ?? 0
    }

    /// Records a habit as kept, extending its streak and restoring its freshness.
    ///
    /// Marking one already kept today does nothing, so a second tap cannot inflate a run.
    /// - Parameter thought: The habit to mark.
    public func markKept(_ thought: Thought) async {
        guard !isKeptToday(thought) else { return }

        var kept = thought
        kept.markHabitKept(at: clock.now)
        guard await (try? repository.update(kept)) != nil else { return }

        if let index = habits.firstIndex(where: { $0.id == thought.id }) {
            habits[index] = kept
        }
        markedCount += 1
        changes.notify()
    }
}
