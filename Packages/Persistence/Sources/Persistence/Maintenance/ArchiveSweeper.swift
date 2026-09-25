import Core
import Foundation

/// Moves thoughts that have run out of freshness into the archive.
///
/// Archiving is the only thing decay is permitted to do. Nothing here deletes: an expired thought
/// remains searchable forever, it simply stops occupying the inbox.
public struct ArchiveSweeper: ArchiveSweeping {
    private let repository: any ThoughtRepository
    private let engine: DecayEngine
    private let clock: any WallClock

    /// Creates a sweeper.
    /// - Parameters:
    ///   - repository: Storage to read from and write back to.
    ///   - engine: Decides which thoughts have expired.
    ///   - clock: Time source used to evaluate expiry.
    public init(repository: any ThoughtRepository, engine: DecayEngine, clock: any WallClock) {
        self.repository = repository
        self.engine = engine
        self.clock = clock
    }

    /// Archives expired thoughts, leaving to-dos available for explicit daily review.
    /// - Returns: The thoughts that were archived, in the order they were processed.
    @discardableResult
    public func sweep() async throws -> [Thought] {
        let now = clock.now
        let live = try await repository.thoughts(in: .live)
        let expired = live.filter { $0.kind != .todo && engine.shouldArchive($0, at: now) }

        var archived: [Thought] = []
        for thought in expired {
            var stale = thought
            stale.archive(at: now)
            try await repository.update(stale)
            archived.append(stale)
        }

        return archived
    }
}
