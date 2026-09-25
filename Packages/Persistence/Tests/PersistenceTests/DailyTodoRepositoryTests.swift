import Core
import Foundation
@testable import Persistence
import SwiftData
import Testing

@Suite("Persistent daily checklist")
struct DailyTodoRepositoryTests {
    private let now = Date(timeIntervalSince1970: 1_790_102_400)
    private let today = PlanDay(rawValue: 20_260_922)

    @Test("decisions from a second repository are visible without recreating the app repository")
    func widgetRoundTrip() async throws {
        let container = try ModelContainerFactory.inMemory()
        let app = SwiftDataDailyTodoRepository(modelContainer: container)
        let widget = SwiftDataDailyTodoRepository(modelContainer: container)
        let task = DailyTodo(text: "Send draft", createdAt: now, day: today)
        try await app.add(task)
        #expect(try await app.all() == [task])
        _ = try await widget.decide(id: task.id, decision: .finish, today: today, at: now)
        #expect(try await app.all().first?.completedAt == now)
        _ = try await app.decide(
            id: task.id,
            decision: .carryForward,
            today: PlanDay(rawValue: 20_260_923),
            at: now
        )
        #expect(try await widget.all().first?.day == today)
        #expect(try await widget.all().first?.isDone == true)
    }

    @Test("tasks persist after the container closes as the same thoughts")
    func diskPersistence() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema(versionedSchema: ThoughtSchemaV5.self)
        let configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "test.store"))
        let task = DailyTodo(text: "Pack bag", createdAt: now, day: today)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let repository = SwiftDataDailyTodoRepository(modelContainer: container)
        try await repository.add(task)
        let reopened = try ModelContainer(for: schema, configurations: configuration)
        #expect(try await SwiftDataDailyTodoRepository(modelContainer: reopened).all() == [task])
        #expect(try await SwiftDataThoughtRepository(modelContainer: reopened).all().map(\.id) == [task.id])
        try await repository.delete(id: task.id)
        #expect(try await repository.all().isEmpty)
    }

    @Test("capture, edits, completion and deletion share a single record")
    func sharedLifecycle() async throws {
        let container = try ModelContainerFactory.inMemory()
        let thoughts = SwiftDataThoughtRepository(modelContainer: container)
        let plan = SwiftDataDailyTodoRepository(modelContainer: container)
        var thought = Thought(body: "Call dentist", capturedAt: now, kind: .todo)
        try await thoughts.add(thought)
        #expect(try await plan.all().first?.id == thought.id)
        #expect(try await plan.all().first?.day == PlanDay(now))
        thought.revise(body: "Call dentist tomorrow", at: now)
        try await thoughts.update(thought)
        #expect(try await plan.all().first?.text == thought.body)
        _ = try await plan.decide(id: thought.id, decision: .finish, today: today, at: now)
        #expect(try await thoughts.all().first?.state == .done(at: now))
        #expect(try await thoughts.all().first?.body == thought.body)
        _ = try await plan.decide(id: thought.id, decision: .reopen, today: today, at: now)
        #expect(try await thoughts.all().first?.state == .inbox)
        try await thoughts.delete(id: thought.id)
        #expect(try await plan.all().isEmpty)
    }

    @Test("legacy tasks import once without losing completion or resurrecting deletions")
    func legacyImport() async throws {
        let container = try ModelContainerFactory.inMemory()
        let task = DailyTodo(text: "Legacy task", createdAt: now, day: today, completedAt: now)
        let context = ModelContext(container)
        let row = ThoughtSchemaV5.DailyTodoEntity(id: task.id, createdAt: now)
        row.payload = try JSONEncoder().encode(task)
        context.insert(row)
        try context.save()
        let plan = SwiftDataDailyTodoRepository(modelContainer: container)
        #expect(try await plan.all() == [task])
        #expect(try await plan.all() == [task])
        let thoughts = SwiftDataThoughtRepository(modelContainer: container)
        #expect(try await thoughts.all().count == 1)
        try await thoughts.delete(id: task.id)
        #expect(try await plan.all().isEmpty)
        #expect(try ModelContext(container).fetch(FetchDescriptor<ThoughtSchemaV5.DailyTodoEntity>()).isEmpty)
    }

    @Test("overdue tasks survive decay until an explicit review choice")
    func reviewBeforeCarry() async throws {
        let thoughts = InMemoryThoughtRepository()
        let plan = ThoughtDailyTodoRepository(thoughts: thoughts)
        let task = DailyTodo(text: "Old task", createdAt: now, day: today)
        try await plan.add(task)
        let later = now.addingTimeInterval(100 * .day)
        let sweeper = ArchiveSweeper(
            repository: thoughts,
            engine: DecayEngine(),
            clock: PlanTestClock(now: later)
        )
        #expect(try await sweeper.sweep().isEmpty)
        #expect(try await plan.all().first?.day == today)
        _ = try await plan.decide(id: task.id, decision: .carryForward, today: PlanDay(later), at: later)
        #expect(try await plan.all().first?.day == PlanDay(later))
        #expect(try await thoughts.all().count == 1)
    }

    @Test("changing kind or archiving in Thoughts removes the task from Plan")
    func sharedVisibility() async throws {
        let thoughts = InMemoryThoughtRepository()
        let plan = ThoughtDailyTodoRepository(thoughts: thoughts)
        var thought = Thought(body: "A task", capturedAt: now, kind: .todo)
        try await thoughts.add(thought)
        thought.confirmKind(.idea, at: now)
        try await thoughts.update(thought)
        #expect(try await plan.all().isEmpty)
        thought.confirmKind(.todo, at: now)
        thought.archive(at: now)
        try await thoughts.update(thought)
        #expect(try await plan.all().isEmpty)
    }
}

private struct PlanTestClock: WallClock { let now: Date }
