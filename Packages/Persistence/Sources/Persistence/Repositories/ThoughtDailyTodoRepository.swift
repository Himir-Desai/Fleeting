import Core
import Foundation

/// Presents the shared thought store as a dated checklist, without copying task records.
public struct ThoughtDailyTodoRepository: DailyTodoRepository {
    private let thoughts: any ThoughtRepository
    private let clock: any WallClock

    public init(thoughts: any ThoughtRepository, clock: any WallClock = SystemClock()) {
        self.thoughts = thoughts
        self.clock = clock
    }

    public func all() async throws -> [DailyTodo] {
        try await thoughts.all().compactMap { thought in
            guard thought.kind == .todo else { return nil }
            if case .done = thought.state {
                return Self.task(thought)
            }
            guard thought.isAwake(at: clock.now) else { return nil }
            return Self.task(thought)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    public func add(_ todo: DailyTodo) async throws {
        guard try await thoughts.all().contains(where: { $0.id == todo.id }) == false else { return }
        try await thoughts.add(Self.thought(todo))
    }

    public func decide(
        id: UUID, decision: DailyTodoDecision, today: PlanDay, at date: Date
    ) async throws -> DailyTodo {
        guard var thought = try await thoughts.all().first(where: { $0.id == id && $0.kind == .todo })
        else { throw PersistenceError.dailyTodoNotFound(id) }
        var task = Self.task(thought)
        task.apply(decision, today: today, at: date)
        switch decision {
        case .finish:
            if let completedAt = task.completedAt {
                thought.complete(at: completedAt)
            }
        case .reopen:
            thought.restore(at: date)
        case .carryForward:
            thought.dueAt = task.day.date()
            thought.markActed(at: date)
        }
        try await thoughts.update(thought)
        return Self.task(thought)
    }

    public func delete(id: UUID) async throws {
        try await thoughts.delete(id: id)
    }

    /// Reads the same text, due day and completion state used by Thoughts.
    static func task(_ thought: Thought) -> DailyTodo {
        let completedAt: Date? = if case let .done(at) = thought.state {
            at
        } else {
            nil
        }
        return DailyTodo(
            id: thought.id, text: thought.body, createdAt: thought.capturedAt,
            day: PlanDay(thought.dueAt ?? thought.capturedAt), completedAt: completedAt
        )
    }

    /// Creates a confirmed to-do so later classification cannot change its type.
    static func thought(_ task: DailyTodo) -> Thought {
        Thought(
            id: task.id, body: task.text, capturedAt: task.createdAt, kind: .todo,
            state: task.completedAt.map { .done(at: $0) } ?? .inbox,
            kindSource: .confirmed, dueAt: task.day.date()
        )
    }
}
