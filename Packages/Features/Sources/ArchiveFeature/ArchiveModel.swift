import Core
import Foundation
import Observation

/// State and rules for browsing thoughts that have left play.
///
/// Decay archives; it never deletes. Everything here remains searchable indefinitely, and can be
/// brought back to the inbox at full freshness.
@MainActor
@Observable
public final class ArchiveModel {
    /// Archived thoughts matching the current query, most recently captured first.
    public private(set) var results: [Thought] = []

    /// Whether a search has completed at least once.
    public private(set) var hasLoaded = false

    /// The most recent failure, or `nil` if the last operation succeeded.
    public internal(set) var lastError: (any Error)?

    /// The current search text. Setting it does not search; call ``search()``.
    public var query: String = ""

    private let repository: any ThoughtRepository
    private let clock: any WallClock

    /// Creates the archive's state.
    /// - Parameters:
    ///   - repository: Where archived thoughts are read from.
    ///   - clock: Time source used when a thought is restored.
    public init(repository: any ThoughtRepository, clock: any WallClock) {
        self.repository = repository
        self.clock = clock
    }

    /// Runs the current query against the archive.
    public func search() async {
        do {
            results = try await repository.search(query, in: .archived)
            lastError = nil
        } catch {
            lastError = error
        }
        hasLoaded = true
    }

    /// Returns a thought to the inbox at full freshness.
    /// - Parameter thought: The archived thought to revive.
    public func restore(_ thought: Thought) async {
        var restored = thought
        restored.restore(at: clock.now)

        do {
            try await repository.update(restored)
            results.removeAll { $0.id == restored.id }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Permanently removes an archived thought.
    /// - Parameter thought: The thought to destroy.
    public func delete(_ thought: Thought) async {
        do {
            try await repository.delete(id: thought.id)
            results.removeAll { $0.id == thought.id }
            lastError = nil
        } catch {
            lastError = error
        }
    }
}
