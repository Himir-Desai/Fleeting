import Core
import Foundation
@testable import Persistence
import Testing

@Suite("Thought lists")
struct ThoughtListRepositoryTests {
    private let now = Date(timeIntervalSince1970: 1_790_102_400)

    @Test("lists persist, rename by identity, and deletion keeps live and completed thoughts")
    func lifecycle() async throws {
        let container = try ModelContainerFactory.inMemory()
        let repository = SwiftDataThoughtRepository(modelContainer: container)
        let list = try await repository.createList(named: "  Work  ")
        let live = Thought(body: "Draft", capturedAt: now, listID: list.id)
        let done = Thought(body: "Sent", capturedAt: now, kind: .todo, state: .done(at: now), listID: list.id)
        try await repository.add(live)
        try await repository.add(done)
        let second = SwiftDataThoughtRepository(modelContainer: container)
        #expect(try await second.lists().contains(list))
        var renamed = list
        renamed.name = "Writing"
        try await second.saveList(renamed)
        #expect(try await repository.lists().contains(renamed))
        try await repository.deleteList(id: list.id)
        let remaining = try await second.all()
        #expect(Set(remaining.map(\.id)) == [live.id, done.id])
        #expect(remaining.allSatisfy { $0.listID == nil })
        #expect(remaining.first { $0.id == done.id }?.state == .done(at: now))
    }

    @Test("Plan is stable and protected; names are validated in both stores")
    func validation() async throws {
        let container = try ModelContainerFactory.inMemory()
        for repository: any ThoughtListRepository in [
            SwiftDataThoughtRepository(modelContainer: container),
            InMemoryThoughtRepository()
        ] {
            #expect(try await repository.lists() == [.plan])
            _ = try await repository.createList(named: "Work")
            await #expect(throws: ThoughtListError.duplicateName) {
                try await repository.createList(named: " work ")
            }
            await #expect(throws: ThoughtListError.emptyName) { try await repository.createList(named: " ") }
            await #expect(throws: ThoughtListError.duplicateName) {
                try await repository.createList(named: "plan")
            }
            await #expect(throws: ThoughtListError.builtInList) {
                try await repository.deleteList(id: ThoughtList.planID)
            }
        }
    }

    @Test("descriptions and default types survive reopen and rename in both stores")
    func metadata() async throws {
        let container = try ModelContainerFactory.inMemory()
        let persistent = SwiftDataThoughtRepository(modelContainer: container)
        for repository: any ThoughtListRepository in [persistent, InMemoryThoughtRepository()] {
            let list = try await repository.createList(
                named: "Work",
                description: "Drafts and projects",
                defaultKind: .todo
            )
            #expect(try await repository.lists().contains(list))
            var edited = list
            edited.name = "Projects"
            edited.description = "Ideas for work"
            edited.defaultKind = .idea
            try await repository.saveList(edited)
            #expect(try await repository.lists().contains(edited))
        }
        let reopened = SwiftDataThoughtRepository(modelContainer: container)
        let list = try #require(try await reopened.lists().first { !$0.isBuiltIn })
        #expect(list.name == "Projects")
        #expect(list.description == "Ideas for work")
        #expect(list.defaultKind == .idea)
    }

    @Test("the checklist adapter only reads and changes tasks in its chosen list")
    func scopedChecklist() async throws {
        let repository = InMemoryThoughtRepository()
        let custom = try await repository.createList(named: "Work")
        let plan = ThoughtListTaskRepository(thoughts: repository)
        let work = ThoughtListTaskRepository(thoughts: repository, listID: custom.id)
        let task = DailyTodo(text: "Work task", createdAt: now, day: PlanDay(now))
        try await work.add(task)
        try await repository.add(Thought(body: "Unfiled todo", capturedAt: now, kind: .todo))
        #expect(try await plan.all().isEmpty)
        #expect(try await work.all() == [task])
        await #expect(throws: PersistenceError.dailyTodoNotFound(task.id)) {
            try await plan.decide(id: task.id, decision: .finish, today: PlanDay(now), at: now)
        }
        await #expect(throws: PersistenceError.dailyTodoNotFound(task.id)) {
            try await plan.delete(id: task.id)
        }
        #expect(try await repository.all().count == 2)
    }
}
