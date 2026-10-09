import Core
import Foundation
@testable import InboxFeature
import Testing

@MainActor
@Suite("Thought list filtering")
struct InboxListTests {
    @Test("list selection combines with kind and archive filters and keeps the global source intact")
    func combinedFilters() async {
        let now = Date(timeIntervalSince1970: 1_790_102_400)
        let listID = UUID()
        let idea = Thought(body: "Listed idea", capturedAt: now, kind: .idea, listID: listID)
        let todo = Thought(body: "Listed todo", capturedAt: now, kind: .todo, listID: listID)
        let archive = Thought(
            body: "Listed archive",
            capturedAt: now,
            state: .archived(at: now),
            listID: listID
        )
        let other = Thought(body: "Unfiled", capturedAt: now)
        let model = InboxModel(
            repository: SpyRepository([idea, todo, archive, other]),
            sweeper: NoopSweeper(),
            clock: StubClock(now: now)
        )
        await model.load()
        model.selectedListID = listID
        #expect(Set(model.filteredThoughts.map(\.id)) == [idea.id, todo.id])
        #expect(model.liveCount == 2)
        model.filter = .kind(.todo)
        #expect(model.filteredThoughts == [todo])
        model.filter = .archived
        #expect(model.filteredThoughts == [archive])
        #expect(model.archivedCount == 1)
        model.selectedListID = nil
        model.filter = .all
        #expect(model.liveCount == 3)
        #expect(model.thoughts.count == 3)
    }

    @Test("moving an existing thought keeps text, history and an unsaved draft")
    func moveExistingThought() async throws {
        let now = Date(timeIntervalSince1970: 1_790_102_400)
        let original = Thought(body: "Stored words", capturedAt: now, kind: .todo, state: .done(at: now))
        let repository = SpyRepository([original])
        let model = ThoughtDetailModel(thought: original, repository: repository, clock: StubClock(now: now))
        model.draft = "Uncommitted revision"
        let listID = UUID()
        await model.moveToList(listID)
        let stored = try #require(try await repository.all().first)
        #expect(stored.body == original.body)
        #expect(stored.state == original.state)
        #expect(stored.capturedAt == original.capturedAt)
        #expect(stored.listID == listID)
        #expect(model.draft == "Uncommitted revision")
        let failed = ThoughtDetailModel(
            thought: original,
            repository: SpyRepository([original], failing: .update),
            clock: StubClock(now: now)
        )
        await failed.moveToList(listID)
        #expect(failed.thought == original)
        #expect(failed.listError != nil)
    }

    @Test("moving an idea into Plan makes it a dated task and retyping it removes it from Plan")
    func moveIntoPlan() async throws {
        let now = Date(timeIntervalSince1970: 1_790_102_400)
        let original = Thought(body: "Turn this into action", capturedAt: now, kind: .idea)
        let repository = SpyRepository([original])
        let model = ThoughtDetailModel(thought: original, repository: repository, clock: StubClock(now: now))
        await model.moveToList(ThoughtList.planID)
        #expect(model.thought.kind == .todo)
        #expect(model.thought.kindSource == .confirmed)
        #expect(model.thought.listID == ThoughtList.planID)
        #expect(try PlanDay(#require(model.thought.dueAt)) == PlanDay(now))
        await model.chooseKind(.idea)
        #expect(model.thought.listID == nil)
        #expect(model.thought.body == original.body)
    }

    @Test("failed detail actions remain visible without presenting an unsaved state as complete")
    func failedDetailActionKeepsThought() async {
        let now = Date(timeIntervalSince1970: 1_790_102_400)
        let original = Thought(body: "Do this later", capturedAt: now, kind: .todo)
        let repository = SpyRepository([original], failing: [.update, .delete])
        let model = ThoughtDetailModel(thought: original, repository: repository, clock: StubClock(now: now))
        #expect(await model.complete() == false)
        #expect(model.thought == original)
        #expect(await model.archive() == false)
        #expect(model.thought == original)
        #expect(await model.delete() == false)
        #expect(model.lastError != nil)
    }
}
