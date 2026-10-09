import Core
import Foundation
@testable import InboxFeature
import Testing

@MainActor
@Suite("Cloud changes in an open thought")
struct CloudDetailTests {
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
