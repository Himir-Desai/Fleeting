import Core
import Foundation

/// A volatile daily checklist for previews, tests and a degraded store.
public actor InMemoryDailyTodoRepository: DailyTodoRepository {
    private var values: [UUID: DailyTodo] = [:]

    public init() {}

    public func all() async throws -> [DailyTodo] {
        values.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func add(_ todo: DailyTodo) async throws {
        values[todo.id] = todo
    }

    public func decide(
        id: UUID, decision: DailyTodoDecision, today: PlanDay, at date: Date
    ) async throws -> DailyTodo {
        guard var todo = values[id] else { throw PersistenceError.dailyTodoNotFound(id) }
        todo.apply(decision, today: today, at: date)
        values[id] = todo
        return todo
    }

    public func delete(id: UUID) async throws {
        values.removeValue(forKey: id)
    }
}
