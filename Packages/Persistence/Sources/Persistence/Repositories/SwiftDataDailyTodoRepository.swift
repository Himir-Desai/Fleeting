import Core
import Foundation
import SwiftData

/// Adapts the shared thought store, importing earlier standalone checklist rows atomically.
@ModelActor
public actor SwiftDataDailyTodoRepository: DailyTodoRepository {
    public func all() async throws -> [DailyTodo] {
        try migrateLegacyTasks()
        return try await shared.all()
    }

    public func add(_ todo: DailyTodo) async throws {
        try migrateLegacyTasks()
        try await shared.add(todo)
    }

    public func decide(
        id: UUID, decision: DailyTodoDecision, today: PlanDay, at date: Date
    ) async throws -> DailyTodo {
        try migrateLegacyTasks()
        return try await shared.decide(id: id, decision: decision, today: today, at: date)
    }

    public func delete(id: UUID) async throws {
        try migrateLegacyTasks()
        try await shared.delete(id: id)
    }

    private var shared: ThoughtDailyTodoRepository {
        ThoughtDailyTodoRepository(thoughts: SwiftDataThoughtRepository(modelContainer: modelContainer))
    }

    /// Moves legacy rows in one save, retaining identities and preferring already-shared edits.
    private func migrateLegacyTasks() throws {
        let context = ModelContext(modelContainer)
        let legacy = try context.fetch(FetchDescriptor<ThoughtSchemaV5.DailyTodoEntity>())
        guard !legacy.isEmpty else { return }
        var ids = try Set(context.fetch(FetchDescriptor<ThoughtEntity>()).map(\.id))
        for row in legacy {
            let task = try JSONDecoder().decode(DailyTodo.self, from: row.payload)
            if ids.insert(task.id).inserted {
                context.insert(ThoughtEntity(ThoughtDailyTodoRepository.thought(task)))
            }
            context.delete(row)
        }
        try context.save()
    }
}
