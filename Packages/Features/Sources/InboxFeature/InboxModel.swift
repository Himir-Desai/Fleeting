import Core
import Foundation
import Observation

/// State and rules for the list of captured thoughts.
@MainActor
@Observable
public final class InboxModel {
    /// Every stored thought, most recently captured first.
    public private(set) var thoughts: [Thought] = []

    /// Whether the first load has completed, so an empty list can be told apart from an unread one.
    public private(set) var hasLoaded = false

    /// The most recent failure, or `nil` if the last operation succeeded.
    public internal(set) var lastError: (any Error)?

    private let repository: any ThoughtRepository
    private let clock: any WallClock

    /// Creates the inbox's state.
    /// - Parameters:
    ///   - repository: Where thoughts are read from and written back to.
    ///   - clock: Time source used when a revision counts as deliberate action.
    public init(repository: any ThoughtRepository, clock: any WallClock) {
        self.repository = repository
        self.clock = clock
    }

    /// Reloads every thought from storage.
    public func load() async {
        do {
            thoughts = try await repository.all()
            lastError = nil
        } catch {
            lastError = error
        }
        hasLoaded = true
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

        do {
            try await repository.update(revised)
            if let index = thoughts.firstIndex(where: { $0.id == revised.id }) {
                thoughts[index] = revised
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }
}
