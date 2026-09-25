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
        let context = ModelContext(modelContainer)
        context.insert(ThoughtEntity(thought))
        try context.save()
    }

    public func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        try fetch(scope: scope, query: nil)
    }

    /// Matches the query inside the store rather than in memory, so the archive stays searchable
    /// as it grows.
    public func search(_ query: String, in scope: ThoughtScope) async throws -> [Thought] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return try fetch(scope: scope, query: trimmed.isEmpty ? nil : trimmed)
    }

    public func update(_ thought: Thought) async throws {
        let context = ModelContext(modelContainer)
        guard let entity = try entity(for: thought.id, context: context) else {
            throw PersistenceError.thoughtNotFound(thought.id)
        }
        entity.overwrite(with: thought)
        try context.save()
    }

    public func delete(id: Thought.ID) async throws {
        let context = ModelContext(modelContainer)
        guard let entity = try entity(for: id, context: context) else {
            throw PersistenceError.thoughtNotFound(id)
        }
        context.delete(entity)
        try context.save()
    }

    /// Fetches rows matching a scope and an optional text query.
    /// - Parameters:
    ///   - scope: Which part of the collection to read.
    ///   - query: Text the raw captured body must contain, or `nil` for no text filter.
    /// - Returns: Matching thoughts, newest capture first.
    private func fetch(scope: ThoughtScope, query: String?) throws -> [Thought] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ThoughtEntity>(
            predicate: Self.predicate(scope: scope, query: query),
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.domain)
    }

    /// Builds the store predicate for a scope and optional text query.
    ///
    /// Written as one explicit predicate per combination rather than a single composed boolean.
    /// SwiftData compiles these to SQL, and a composed expression mixing captured booleans with a
    /// collection membership test crashes that compiler.
    /// - Parameters:
    ///   - scope: Which part of the collection to read.
    ///   - query: Text the raw captured body must contain, or `nil` for no text filter.
    /// - Returns: The predicate, or `nil` when nothing needs filtering.
    private static func predicate(scope: ThoughtScope, query: String?) -> Predicate<ThoughtEntity>? {
        switch (scope, query) {
        case (.all, .none):
            return nil
        case let (.all, .some(text)):
            return #Predicate { $0.body.localizedStandardContains(text) }
        case (.live, .none):
            return #Predicate { $0.isLive }
        case let (.live, .some(text)):
            return #Predicate { $0.isLive && $0.body.localizedStandardContains(text) }
        case (.archived, .none):
            return #Predicate { !$0.isLive }
        case let (.archived, .some(text)):
            return #Predicate { !$0.isLive && $0.body.localizedStandardContains(text) }
        }
    }

    /// Fetches the row for an identity.
    /// - Parameter id: Identity to look up.
    /// - Returns: The stored row, or `nil` if no row matches.
    private func entity(for id: Thought.ID, context: ModelContext) throws -> ThoughtEntity? {
        var descriptor = FetchDescriptor<ThoughtEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
