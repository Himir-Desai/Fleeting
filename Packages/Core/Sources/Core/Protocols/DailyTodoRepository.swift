import Foundation

/// Storage for the daily checklist, shared by the app and its widgets.
public protocol DailyTodoRepository: Sendable {
    func all() async throws -> [DailyTodo]
    func add(_ todo: DailyTodo) async throws
    /// Applies a decision to the latest stored value, not a stale screen or widget snapshot.
    @discardableResult
    func decide(id: UUID, decision: DailyTodoDecision, today: PlanDay, at date: Date) async throws
        -> DailyTodo
    func delete(id: UUID) async throws
}
