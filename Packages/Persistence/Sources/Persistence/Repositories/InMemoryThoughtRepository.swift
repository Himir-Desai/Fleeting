import Core
import Foundation

/// A `ThoughtRepository` held entirely in memory.
///
/// Used by SwiftUI previews and by tests that need repository behaviour without a store.
/// The SwiftData-backed implementation arrives in Phase 1.
public actor InMemoryThoughtRepository: ThoughtRepository, ThoughtListRepository {
    private var collections: [UUID: ThoughtList] = [:]
    private var storage: [Thought.ID: Thought]

    /// Creates a repository pre-populated with the given thoughts.
    /// - Parameter seed: Thoughts to start with. Defaults to empty.
    public init(seed: [Thought] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func lists() async throws -> [ThoughtList] {
        [ThoughtList.plan] + collections.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    public func saveList(_ list: ThoughtList) async throws {
        guard !list.isBuiltIn else { throw ThoughtListError.builtInList }
        var normalized = list
        normalized.name = list.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.description = list.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.name.isEmpty else { throw ThoughtListError.emptyName }
        guard normalized.name.localizedCaseInsensitiveCompare(ThoughtList.plan.name) != .orderedSame,
              !collections.values.contains(where: {
                  $0.id != list.id && $0.name.localizedCaseInsensitiveCompare(normalized.name) == .orderedSame
              }) else { throw ThoughtListError.duplicateName }
        collections[list.id] = normalized
    }

    public func deleteList(id: UUID) async throws {
        guard id != ThoughtList.planID else { throw ThoughtListError.builtInList }
        collections[id] = nil
        for (key, var thought) in storage where thought.listID == id {
            thought.listID = nil
            storage[key] = thought
        }
    }

    public func add(_ thought: Thought) async throws {
        storage[thought.id] = thought
    }

    public func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        storage.values
            .filter { scope.contains($0.state) }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    public func update(_ thought: Thought) async throws {
        storage[thought.id] = thought
    }

    public func delete(id: Thought.ID) async throws {
        storage[id] = nil
    }
}
