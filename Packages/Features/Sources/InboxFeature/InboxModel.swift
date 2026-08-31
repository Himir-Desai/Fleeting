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

    /// How many thoughts a review session would contain right now.
    public private(set) var reviewCount = 0

    /// Archived thoughts, loaded so the Archived filter can show them inline. Never mixed into the
    /// live list — they appear only when that filter is chosen.
    public private(set) var archivedThoughts: [Thought] = []

    /// Which filter the list is showing.
    public var filter: InboxFilter = .all

    /// Whether the current filter is the archive, so callers can pick restore/delete row actions.
    public var isShowingArchive: Bool {
        filter == .archived
    }

    /// The thoughts to show for the current filter, newest first.
    ///
    /// "All" and each kind draw from the live list only; "Archived" draws from the archive.
    /// Unsorted thoughts have no chip of their own — they appear under All.
    public var filteredThoughts: [Thought] {
        switch filter {
        case .all: thoughts
        case let .kind(kind): thoughts.filter { $0.kind == kind }
        case .archived: archivedThoughts
        }
    }

    /// How many live thoughts there are in total, across every kind.
    public var liveCount: Int {
        thoughts.count
    }

    /// How many archived thoughts there are, for the Archived chip's count.
    public var archivedCount: Int {
        archivedThoughts.count
    }

    /// How many live thoughts are in the fading or expiring bands, for the masthead.
    public var fadingCount: Int {
        thoughts.reduce(into: 0) { total, thought in
            switch freshness(of: thought).band {
            case .fading, .expiring: total += 1
            default: break
            }
        }
    }

    /// How many live thoughts are of a given kind, for a filter chip's count.
    /// - Parameter kind: The kind to count.
    /// - Returns: The number of live thoughts of that kind.
    public func count(of kind: ThoughtKind) -> Int {
        thoughts.reduce(into: 0) { total, thought in
            if thought.kind == kind {
                total += 1
            }
        }
    }

    private let repository: any ThoughtRepository
    private let sweeper: any ArchiveSweeping
    private let engine: DecayEngine
    private let selector: ReviewSelector
    private let clock: any WallClock

    /// Creates the inbox's state.
    /// - Parameters:
    ///   - repository: Where thoughts are read from and written back to.
    ///   - sweeper: Archives expired thoughts before each load.
    ///   - engine: Computes freshness for display.
    ///   - selector: Counts how many thoughts need a decision.
    ///   - clock: Time source used for freshness and for deliberate actions.
    public init(
        repository: any ThoughtRepository,
        sweeper: any ArchiveSweeping,
        engine: DecayEngine = DecayEngine(),
        selector: ReviewSelector = ReviewSelector(),
        clock: any WallClock
    ) {
        self.repository = repository
        self.sweeper = sweeper
        self.engine = engine
        self.selector = selector
        self.clock = clock
    }

    /// Sweeps expired thoughts into the archive, then reloads both the live list and the archive.
    ///
    /// The archive is loaded here too so switching to its filter is instant; it is only shown when
    /// that filter is chosen.
    ///
    /// Thoughts inside a running snooze are dropped from the live list. The `.live` scope is a
    /// storage question and includes them, because a stored column cannot know when a snooze
    /// lapses; keeping them would put a thought the user set aside back in the list on the very
    /// next load.
    public func load() async {
        do {
            try await sweeper.sweep()
            let now = clock.now
            thoughts = try await repository.thoughts(in: .live).filter { $0.isAwake(at: now) }
            archivedThoughts = try await repository.thoughts(in: .archived)
            reviewCount = selector.count(from: thoughts, at: now)
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

    /// Records a person's decision about what a thought is.
    ///
    /// The correction is remembered: classification will not overwrite it later.
    /// - Parameters:
    ///   - kind: The kind the user chose.
    ///   - thought: The thought being corrected.
    public func confirmKind(_ kind: ThoughtKind, for thought: Thought) async {
        guard kind != thought.kind else { return }
        var corrected = thought
        corrected.confirmKind(kind, at: clock.now)
        await persist(corrected, removingFromList: false)
    }

    /// Marks a todo complete, taking it out of the live list without destroying it.
    /// - Parameter thought: The todo to complete.
    public func complete(_ thought: Thought) async {
        var completed = thought
        completed.complete(at: clock.now)
        await persist(completed, removingFromList: true)
    }

    /// Records a habit as kept, extending its streak and restoring its freshness.
    /// - Parameter thought: The habit to mark.
    public func markHabitKept(_ thought: Thought) async {
        var kept = thought
        kept.markHabitKept(at: clock.now)
        await persist(kept, removingFromList: false)
    }

    /// Permanently removes a thought. The only path in the app that destroys anything.
    /// - Parameter thought: The thought to delete.
    public func delete(_ thought: Thought) async {
        do {
            try await repository.delete(id: thought.id)
            thoughts.removeAll { $0.id == thought.id }
            archivedThoughts.removeAll { $0.id == thought.id }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Brings an archived thought back to the inbox at full freshness.
    /// - Parameter thought: The archived thought to revive.
    public func restore(_ thought: Thought) async {
        var restored = thought
        restored.restore(at: clock.now)
        do {
            try await repository.update(restored)
            archivedThoughts.removeAll { $0.id == thought.id }
            thoughts.insert(restored, at: 0)
            reviewCount = selector.count(from: thoughts, at: clock.now)
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
                // The archive is a filter on this same screen now, so a thought that has just
                // been archived has to land in the archived list immediately. Without this the
                // Archived chip stays stale until the next load.
                if case .archived = thought.state {
                    archivedThoughts.insert(thought, at: 0)
                }
            } else if let index = thoughts.firstIndex(where: { $0.id == thought.id }) {
                thoughts[index] = thought
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }
}
