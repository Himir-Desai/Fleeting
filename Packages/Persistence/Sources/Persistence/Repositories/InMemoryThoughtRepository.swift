import Core
import Foundation

/// A `ThoughtRepository` held entirely in memory.
///
/// Used by SwiftUI previews and by tests that need repository behaviour without a store.
/// The SwiftData-backed implementation arrives in Phase 1.
public actor InMemoryThoughtRepository: ThoughtRepository {
    private var storage: [Thought.ID: Thought]

    /// Creates a repository pre-populated with the given thoughts.
    /// - Parameter seed: Thoughts to start with. Defaults to empty.
    public init(seed: [Thought] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func add(_ thought: Thought) async throws {
        storage[thought.id] = thought
    }

    public func all() async throws -> [Thought] {
        storage.values.sorted { $0.capturedAt > $1.capturedAt }
    }

    public func update(_ thought: Thought) async throws {
        storage[thought.id] = thought
    }

    public func delete(id: Thought.ID) async throws {
        storage[id] = nil
    }
}
