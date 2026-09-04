import Core
import Foundation
import Observation

/// State and rules for the habits shown on the home screen beside the capture field.
///
/// A habit is the one kind of thought that needs touching regularly, so it is the one kind that
/// earns a place on the screen a cold launch lands on (ADR-0047). Only habits actually *due* are
/// listed: one kept for its current period drops off the moment it is marked, so the home screen
/// is a list of what is outstanding rather than a roll call (ADR-0048).
@MainActor
@Observable
public final class DailyHabitsModel {
    /// Habits waiting to be kept, oldest first. A habit kept for its period is not here.
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

    /// Reloads the habits that are due, awake and live, oldest first.
    ///
    /// Failures are swallowed on purpose: this strip sits on the capture screen, and a read that
    /// fails must never put an error in front of the field (ADR-0008).
    public func load() async {
        let now = clock.now
        let live = await (try? repository.thoughts(in: .live)) ?? []
        habits = live
            .filter { $0.kind == .habit && $0.isAwake(at: now) && $0.isDue(at: now) }
            .sorted { $0.capturedAt < $1.capturedAt }
        hasLoaded = true
    }

    /// How often a habit is meant to be kept, for the card's caption.
    /// - Parameter thought: The habit to read.
    /// - Returns: Its cadence.
    public func cadence(of thought: Thought) -> HabitCadence {
        thought.cadence
    }

    /// How long a habit's run is, counted in its own periods.
    /// - Parameter thought: The habit to read.
    /// - Returns: The streak count, or zero if it has never been kept.
    public func streakCount(of thought: Thought) -> Int {
        thought.streak?.count ?? 0
    }

    /// Records a habit as kept, extending its streak and taking it off the home screen.
    ///
    /// The habit leaves the list as soon as it is marked, because it is no longer due: the home
    /// screen shows what is outstanding, and a kept habit is not (ADR-0048). It is still in the
    /// Thoughts tab, where its streak and cadence live.
    /// - Parameter thought: The habit to mark.
    public func markKept(_ thought: Thought) async {
        guard thought.isDue(at: clock.now) else { return }

        var kept = thought
        kept.markHabitKept(at: clock.now)
        guard await (try? repository.update(kept)) != nil else { return }

        habits.removeAll { $0.id == thought.id }
        markedCount += 1
        changes.notify()
    }
}
