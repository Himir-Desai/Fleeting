import Core
import Foundation
@testable import InboxFeature
import Testing

@MainActor
@Suite("Cloud changes in an open thought")
struct CloudDetailTests {
    @Test("archived and completed editors allow only restoring, including store action guards")
    func restrictedEditor() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for state in [ThoughtState.archived(at: now), .done(at: now)] {
            let original = Thought(body: "Finished", capturedAt: now, kind: .todo, state: state)
            let repository = SpyRepository([original])
            let model = ThoughtDetailModel(
                thought: original,
                repository: repository,
                clock: StubClock(now: now)
            )
            model.draft = "Must not save"
            await model.saveText()
            await model.chooseKind(.idea)
            await model.moveToList(UUID())
            await model.applyExpiry()
            #expect(await model.complete() == false)
            #expect(await model.archive() == false)
            #expect(await model.delete() == false)
            #expect(await model.snooze(forDays: 7) == false)
            #expect(model.isReadOnly)
            #expect(!model.canSaveText)
            #expect(try await repository.all() == [original])
            #expect(await model.restore())
            #expect(model.thought.state == .inbox)
            #expect(model.thought.body == original.body)
        }
    }

    @Test("completion saves the task draft once and never re-completes a finished task")
    func completionPreservesEditedText() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let original = Thought(body: "Original", capturedAt: now, kind: .todo)
        let repository = SpyRepository([original])
        let model = ThoughtDetailModel(thought: original, repository: repository, clock: StubClock(now: now))
        model.draft = "Edited task"
        #expect(await model.complete())
        await model.saveText()
        #expect(await model.complete() == false)
        let stored = try #require(try await repository.all().first)
        #expect(stored.body == "Edited task")
        #expect(stored.state == .done(at: now))
    }

    @Test("a viewer cannot reopen a completed shared task")
    func viewerCannotRestore() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let original = Thought(
            body: "Shared",
            capturedAt: now,
            kind: .todo,
            state: .done(at: now),
            sharing: ListSharing(role: .viewer)
        )
        let model = ThoughtDetailModel(
            thought: original,
            repository: SpyRepository([original]),
            clock: StubClock(now: now)
        )
        #expect(!model.canRestore)
        #expect(await model.restore() == false)
    }

    @Test("remote edits refresh the detail without discarding an unsaved local draft")
    func preserveDraft() async throws {
        var thought = Thought(body: "Original", capturedAt: .distantPast)
        let repository = SpyRepository([thought])
        let model = ThoughtDetailModel(
            thought: thought,
            repository: repository,
            clock: StubClock(now: .distantPast)
        )
        model.draft = "Typing here"
        thought.revise(body: "Other device", at: .distantPast)
        thought.confirmKind(.todo, at: .distantPast)
        try await repository.update(thought)
        await model.reload()
        #expect(model.draft == "Typing here")
        #expect(model.thought.body == "Other device")
        #expect(model.thought.kind == .todo)
        try await repository.delete(id: thought.id)
        await model.reload()
        #expect(model.isDeleted)
    }

    @Test("an untouched draft follows the cloud version")
    func refreshText() async throws {
        var thought = Thought(body: "Original", capturedAt: .distantPast)
        let repository = SpyRepository([thought])
        let model = ThoughtDetailModel(
            thought: thought,
            repository: repository,
            clock: StubClock(now: .distantPast)
        )
        thought.revise(body: "Other device", at: .distantPast)
        try await repository.update(thought)
        await model.reload()
        #expect(model.draft == "Other device")
        #expect(!model.canSaveText)
    }
}
