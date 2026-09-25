import Core
import Foundation
@testable import PlanFeature
import Testing

@MainActor
@Suite("Plan and daily review")
struct PlanModelTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        value.firstWeekday = 2
        return value
    }

    @Test("seven day buttons span the locale's week and crossing midnight queues unfinished tasks")
    func midnightReview() async throws {
        let clock =
            try PlanTestClock(#require(PlanDay(rawValue: 20_260_922).date(timeZone: calendar.timeZone)))
        let repository = PlanTestRepository()
        let model = PlanModel(
            repository: repository,
            changes: ThoughtChangeNotifier(),
            clock: clock,
            calendar: calendar
        )
        #expect(model.week.count == 7)
        #expect(model.week.first == PlanDay(rawValue: 20_260_921))
        model.draft = "Send draft"
        await model.add()
        let original = try #require(model.selectedTodos.first)
        clock.advance(days: 1)
        await model.load()
        #expect(model.selectedTodos.isEmpty)
        #expect(model.pendingReview.map(\.id) == [original.id])
        #expect(model.pendingReview.first?.day == PlanDay(rawValue: 20_260_922))
        await model.decide(original, .carryForward, fromReview: true)
        #expect(model.pendingReview.isEmpty)
        #expect(model.selectedTodos.first?.id == original.id)
        #expect(model.selectedTodos.first?.isDone == false)
    }

    @Test("finishing an overdue item preserves its original day and exposes completed review feedback")
    func finishDuringReview() async throws {
        let clock =
            try PlanTestClock(#require(PlanDay(rawValue: 20_260_922).date(timeZone: calendar.timeZone)))
        let repository = PlanTestRepository()
        let task = DailyTodo(text: "Read draft", createdAt: clock.now, day: PlanDay(rawValue: 20_260_921))
        try await repository.add(task)
        let model = PlanModel(
            repository: repository,
            changes: ThoughtChangeNotifier(),
            clock: clock,
            calendar: calendar
        )
        await model.load()
        await model.decide(task, .finish, fromReview: true)
        #expect(model.pendingReview.isEmpty)
        #expect(model.reviewedDone.first?.isDone == true)
        model.selectedDay = task.day
        #expect(model.selectedTodos.first?.isDone == true)
        let reloaded = PlanModel(
            repository: repository,
            changes: ThoughtChangeNotifier(),
            clock: clock,
            calendar: calendar
        )
        await reloaded.load()
        #expect(reloaded.todos.first?.isDone == true)
        #expect(reloaded.pendingReview.isEmpty)
    }

    @Test("failed writes retain draft and pending review decisions")
    func failedWrites() async throws {
        let clock =
            try PlanTestClock(#require(PlanDay(rawValue: 20_260_922).date(timeZone: calendar.timeZone)))
        let repository = PlanTestRepository()
        let task = DailyTodo(text: "Read draft", createdAt: clock.now, day: PlanDay(rawValue: 20_260_921))
        try await repository.add(task)
        let model = PlanModel(
            repository: repository,
            changes: ThoughtChangeNotifier(),
            clock: clock,
            calendar: calendar
        )
        await model.load()
        await repository.failWrites()
        model.draft = "Do not lose this"
        await model.add()
        #expect(model.draft == "Do not lose this")
        #expect(model.error != nil)
        await model.decide(task, .carryForward, fromReview: true)
        #expect(model.pendingReview.count == 1)
        #expect(model.reviewedDone.isEmpty)
    }

    @Test("selected future day, blank input and past-day entry are handled correctly")
    func inputRules() async throws {
        let clock =
            try PlanTestClock(#require(PlanDay(rawValue: 20_260_922).date(timeZone: calendar.timeZone)))
        let model = PlanModel(
            repository: PlanTestRepository(),
            changes: ThoughtChangeNotifier(),
            clock: clock,
            calendar: calendar
        )
        model.draft = " \n "
        #expect(!model.canAdd)
        model.draft = "Pack bag"
        model.selectedDay = PlanDay(rawValue: 20_260_923)
        await model.add()
        #expect(model.selectedTodos.first?.day == PlanDay(rawValue: 20_260_923))
        model.selectedDay = PlanDay(rawValue: 20_260_921)
        model.draft = "Past task"
        #expect(model.canAdd)
        await model.add()
        #expect(model.todos.count == 2)
        #expect(model.pendingReview.first?.text == "Past task")
    }
}

private final class PlanTestClock: WallClock, @unchecked Sendable {
    // Access is serialized by the @MainActor test suite; repository actors never read the clock.
    private var value: Date
    var now: Date {
        value
    }

    init(_ value: Date) {
        self.value = value
    }

    func advance(days: Int) {
        value = value.addingTimeInterval(Double(days) * 86400)
    }
}

private actor PlanTestRepository: DailyTodoRepository {
    private var values: [UUID: DailyTodo] = [:]
    private var failing = false
    enum Failure: Error { case write }
    func failWrites() {
        failing = true
    }

    func all() async throws -> [DailyTodo] {
        Array(values.values)
    }

    func add(_ todo: DailyTodo) async throws {
        if failing {
            throw Failure.write
        }
        values[todo.id] = todo
    }

    func decide(
        id: UUID,
        decision: DailyTodoDecision,
        today: PlanDay,
        at date: Date
    ) async throws -> DailyTodo {
        if failing {
            throw Failure.write
        }
        var todo = try #require(values[id])
        todo.apply(decision, today: today, at: date)
        values[id] = todo
        return todo
    }

    func delete(id: UUID) async throws {
        values.removeValue(forKey: id)
    }
}
