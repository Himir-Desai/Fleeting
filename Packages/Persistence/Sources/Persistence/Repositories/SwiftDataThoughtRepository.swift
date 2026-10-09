import Core
import Foundation
import SwiftData

/// A ``Core/ThoughtRepository`` backed by SwiftData.
///
/// Declared with `@ModelActor` so every access is serialised on the actor's own executor:
/// SwiftData's `ModelContext` is not safe to share across threads, and this confines it.
@ModelActor
public actor SwiftDataThoughtRepository: ThoughtRepository, ThoughtListRepository {
    public func add(_ thought: Thought) async throws {
        let context = ModelContext(modelContainer)
        try migrateLegacyTasks(in: context)
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
        try migrateLegacyTasks(in: context)
        guard let entity = try entity(for: thought.id, context: context) else {
            throw PersistenceError.thoughtNotFound(thought.id)
        }
        entity.overwrite(with: thought)
        try context.save()
    }

    public func delete(id: Thought.ID) async throws {
        let context = ModelContext(modelContainer)
        try migrateLegacyTasks(in: context)
        guard let entity = try entity(for: id, context: context) else {
            throw PersistenceError.thoughtNotFound(id)
        }
        context.delete(entity)
        try context.save()
    }

    public func lists() async throws -> [ThoughtList] {
        let context = ModelContext(modelContainer)
        let rows = try context.fetch(FetchDescriptor<ThoughtSchemaV8.ThoughtListEntity>())
        // CloudKit may deliver duplicate records for one domain ID; expose each collection once.
        let unique = Dictionary(
            rows.map { (
                $0.id,
                ThoughtList(
                    id: $0.id,
                    name: $0.name,
                    description: $0.listDescription,
                    defaultKind: ThoughtKind(rawValue: $0.defaultKindRaw) ?? .unsorted
                )
            ) },
            uniquingKeysWith: { first, _ in first }
        )
        return [ThoughtList.plan] + unique.filter { $0.key != ThoughtList.planID }
            .map(\.value)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func saveList(_ list: ThoughtList) async throws {
        guard !list.isBuiltIn else { throw ThoughtListError.builtInList }
        let name = list.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ThoughtListError.emptyName }
        let context = ModelContext(modelContainer)
        let rows = try context.fetch(FetchDescriptor<ThoughtSchemaV8.ThoughtListEntity>())
        guard name.localizedCaseInsensitiveCompare(ThoughtList.plan.name) != .orderedSame,
              !rows
              .contains(where: {
                  $0.id != list.id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
              })
        else { throw ThoughtListError.duplicateName }
        let matching = rows.filter { $0.id == list.id }
        if matching.isEmpty {
            context.insert(ThoughtSchemaV8.ThoughtListEntity(
                id: list.id,
                name: name,
                listDescription: list.description.trimmingCharacters(in: .whitespacesAndNewlines),
                defaultKindRaw: list.defaultKind.rawValue
            ))
        } else {
            for row in matching {
                row.name = name
                row.listDescription = list.description.trimmingCharacters(in: .whitespacesAndNewlines)
                row.defaultKindRaw = list.defaultKind.rawValue
            }
        }
        try context.save()
    }

    public func deleteList(id: UUID) async throws {
        guard id != ThoughtList.planID else { throw ThoughtListError.builtInList }
        let context = ModelContext(modelContainer)
        for thought in try context.fetch(FetchDescriptor<ThoughtEntity>()) where thought.listID == id {
            thought.listID = nil
        }
        for row in try context.fetch(FetchDescriptor<ThoughtSchemaV8.ThoughtListEntity>())
            where row.id == id
        {
            context.delete(row)
        }
        try context.save()
    }

    /// Imports old checklist records into the same thought transaction before reading or writing.
    private func migrateLegacyTasks(in context: ModelContext) throws {
        let legacy = try context.fetch(FetchDescriptor<ThoughtSchemaV8.DailyTodoEntity>())
        guard !legacy.isEmpty else { return }
        var ids = try Set(context.fetch(FetchDescriptor<ThoughtEntity>()).map(\.id))
        for row in legacy {
            let task = try JSONDecoder().decode(DailyTodo.self, from: row.payload)
            if ids.insert(task.id).inserted {
                context.insert(ThoughtEntity(ThoughtListTaskRepository.thought(task)))
            }
            context.delete(row)
        }
        try context.save()
    }

    /// Fetches rows matching a scope and an optional text query.
    /// - Parameters:
    ///   - scope: Which part of the collection to read.
    ///   - query: Text the raw captured body must contain, or `nil` for no text filter.
    /// - Returns: Matching thoughts, newest capture first.
    private func fetch(scope: ThoughtScope, query: String?) throws -> [Thought] {
        let context = ModelContext(modelContainer)
        try migrateLegacyTasks(in: context)
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
