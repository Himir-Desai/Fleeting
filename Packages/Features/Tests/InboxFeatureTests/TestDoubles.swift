import Core
import Foundation

/// A failure distinguishable from any real storage error.
struct StorageFailure: Error {}

/// A clock frozen at a chosen instant.
struct StubClock: WallClock {
    let now: Date
}

/// Storage that can be inspected and told to fail.
actor SpyRepository: ThoughtRepository {
    /// Which operations should fail. Scoped per operation so a test can fail exactly the call
    /// it is about without breaking its own setup.
    struct Failures: OptionSet {
        let rawValue: Int
        static let load = Failures(rawValue: 1 << 0)
        static let update = Failures(rawValue: 1 << 1)
        static let delete = Failures(rawValue: 1 << 2)
    }

    private(set) var thoughts: [Thought]
    private(set) var deletedIDs: [Thought.ID] = []
    private let failures: Failures

    init(_ thoughts: [Thought] = [], failing failures: Failures = []) {
        self.thoughts = thoughts
        self.failures = failures
    }

    func add(_ thought: Thought) async throws {
        thoughts.append(thought)
    }

    func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        if failures.contains(.load) {
            throw StorageFailure()
        }
        return thoughts.filter { scope.contains($0.state) }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    func update(_ thought: Thought) async throws {
        if failures.contains(.update) {
            throw StorageFailure()
        }
        guard let index = thoughts.firstIndex(where: { $0.id == thought.id }) else { return }
        thoughts[index] = thought
    }

    func delete(id: Thought.ID) async throws {
        if failures.contains(.delete) {
            throw StorageFailure()
        }
        deletedIDs.append(id)
        thoughts.removeAll { $0.id == id }
    }
}

/// A sweeper that archives nothing, so inbox tests are not entangled with decay.
struct NoopSweeper: ArchiveSweeping {
    func sweep() async throws -> [Thought] {
        []
    }
}

/// A sweeper that reports a failure, to prove the inbox still reports it.
struct FailingSweeper: ArchiveSweeping {
    func sweep() async throws -> [Thought] {
        throw StorageFailure()
    }
}

/// A sweeper that really archives, so the inbox's sweep-then-load order can be observed.
actor RecordingSweeper: ArchiveSweeping {
    private(set) var didSweep = false
    private let repository: SpyRepository
    private let now: Date

    init(repository: SpyRepository, now: Date) {
        self.repository = repository
        self.now = now
    }

    func sweep() async throws -> [Thought] {
        didSweep = true
        let engine = DecayEngine()
        let live = try await repository.thoughts(in: .live)
        let expired = live.filter { engine.shouldArchive($0, at: now) }

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
