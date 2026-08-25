import Core
import Foundation
import Observation

/// State and rules for the list of live thoughts.
@MainActor
@Observable
public final class InboxModel {
    /// Live thoughts, most recently captured first. Archived thoughts are not shown here.
    public private(set) var thoughts: [Thought] = []

    /// Whether the first load has completed, so an empty list can be told apart from an unread one.
    public private(set) var hasLoaded = false

    /// The most recent failure, or `nil` if the last operation succeeded.
    public internal(set) var lastError: (any Error)?

    private let repository: any ThoughtRepository
    private let sweeper: any ArchiveSweeping
    private let engine: DecayEngine
    private let clock: any WallClock

    /// Creates the inbox's state.
    /// - Parameters:
    ///   - repository: Where thoughts are read from and written back to.
    ///   - sweeper: Archives expired thoughts before each load.
    ///   - engine: Computes freshness for display.
    ///   - clock: Time source used for freshness and for deliberate actions.
    public init(
        repository: any ThoughtRepository,
        sweeper: any ArchiveSweeping,
        engine: DecayEngine = DecayEngine(),
        clock: any WallClock
    ) {
        self.repository = repository
        self.sweeper = sweeper
        self.engine = engine
        self.clock = clock
    }

    /// Sweeps expired thoughts into the archive, then reloads what is still live.
    public func load() async {
        do {
            try await sweeper.sweep()
            thoughts = try await repository.thoughts(in: .live)
            lastError = nil
        } catch {
            lastError = error
        }
        hasLoaded = true
    }

    /// How fresh a thought is right now.
    /// - Parameter thought: The thought to evaluate.
    /// - Returns: Freshness within 0...1.
    public func freshness(of thought: Thought) -> Freshness {
        engine.freshness(of: thought, at: clock.now)
    }

    /// When a thought will expire if nothing else happens to it.
    /// - Parameter thought: The thought to evaluate.
    /// - Returns: The expiry instant, or `nil` if it no longer decays.
    public func expiryDate(of thought: Thought) -> Date? {
        engine.expiryDate(of: thought)
    }

    /// Sets a thought aside, holding it at full freshness until the snooze ends.
    /// - Parameters:
    ///   - thought: The thought to snooze.
    ///   - days: How many days to set it aside for.
    public func snooze(_ thought: Thought, forDays days: Double) async {
        var snoozed = thought
        snoozed.snooze(until: clock.now.addingTimeInterval(days * .day), at: clock.now)
        await persist(snoozed, removingFromList: true)
    }

    /// Archives a thought by hand, before decay would have done it.
    /// - Parameter thought: The thought to archive.
    public func archive(_ thought: Thought) async {
        var archived = thought
        archived.archive(at: clock.now)
        await persist(archived, removingFromList: true)
    }

    /// Permanently removes a thought. The only path in the app that destroys anything.
    /// - Parameter thought: The thought to delete.
    public func delete(_ thought: Thought) async {
        do {
            try await repository.delete(id: thought.id)
            thoughts.removeAll { $0.id == thought.id }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Replaces a thought's text with a user-supplied revision, which counts as deliberate action.
    ///
    /// A revision that would leave the thought empty is refused: emptying a thought is a deletion,
    /// and deletion must be explicit.
    /// - Parameters:
    ///   - thought: The thought being revised.
    ///   - newBody: The replacement text.
    public func revise(_ thought: Thought, to newBody: String) async {
        let trimmed = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != thought.body else { return }

        var revised = thought
        revised.revise(body: trimmed, at: clock.now)
        await persist(revised, removingFromList: false)
    }

    /// Writes a changed thought back and reflects it in the list.
    /// - Parameters:
    ///   - thought: The updated thought.
    ///   - removingFromList: Whether the change takes it out of the live list.
    private func persist(_ thought: Thought, removingFromList: Bool) async {
        do {
            try await repository.update(thought)
            if removingFromList {
                thoughts.removeAll { $0.id == thought.id }
            } else if let index = thoughts.firstIndex(where: { $0.id == thought.id }) {
                thoughts[index] = thought
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }
}
