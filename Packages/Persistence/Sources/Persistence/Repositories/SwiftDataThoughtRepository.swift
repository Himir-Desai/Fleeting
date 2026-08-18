import Core
import Foundation
import SwiftData

/// A ``Core/ThoughtRepository`` backed by SwiftData.
///
/// Declared with `@ModelActor` so every access is serialised on the actor's own executor:
/// SwiftData's `ModelContext` is not safe to share across threads, and this confines it.
@ModelActor
public actor SwiftDataThoughtRepository: ThoughtRepository {
    public func add(_ thought: Thought) async throws {
        modelContext.insert(ThoughtEntity(thought))
        try modelContext.save()
    }

    public func all() async throws -> [Thought] {
        let descriptor = FetchDescriptor<ThoughtEntity>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func update(_ thought: Thought) async throws {
        guard let entity = try entity(for: thought.id) else {
            throw PersistenceError.thoughtNotFound(thought.id)
        }
        entity.overwrite(with: thought)
        try modelContext.save()
    }

    public func delete(id: Thought.ID) async throws {
        guard let entity = try entity(for: id) else {
            throw PersistenceError.thoughtNotFound(id)
        }
        modelContext.delete(entity)
        try modelContext.save()
    }

    /// Fetches the row for an identity.
    /// - Parameter id: Identity to look up.
    /// - Returns: The stored row, or `nil` if no row matches.
    private func entity(for id: Thought.ID) throws -> ThoughtEntity? {
        var descriptor = FetchDescriptor<ThoughtEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
