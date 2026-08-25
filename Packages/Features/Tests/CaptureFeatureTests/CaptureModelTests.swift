@testable import CaptureFeature
import Core
import Foundation
import Testing

/// A repository that records what it was asked to store, and can be told to fail.
private actor SpyRepository: ThoughtRepository {
    private(set) var stored: [Thought] = []
    private let failure: (any Error)?

    init(failing failure: (any Error)? = nil) {
        self.failure = failure
    }

    func add(_ thought: Thought) async throws {
        if let failure {
            throw failure
        }
        stored.append(thought)
    }

    func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        stored.filter { scope.contains($0.state) }
    }

    func update(_ thought: Thought) async throws {}
    func delete(id: Thought.ID) async throws {}
}

private struct StubClock: WallClock {
    let now: Date
}

private struct StorageFailure: Error {}

@MainActor
@Suite("CaptureModel")
struct CaptureModelTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeModel(
        repository: SpyRepository = SpyRepository()
    ) -> (CaptureModel, SpyRepository) {
        (CaptureModel(repository: repository, clock: StubClock(now: epoch)), repository)
    }

    @Test("an empty field cannot be saved")
    func emptyIsNotSavable() {
        let (model, _) = makeModel()
        #expect(!model.canSave)
    }

    @Test("whitespace alone is not a thought")
    func whitespaceIsNotSavable() async {
        let (model, repository) = makeModel()
        model.text = "   \n\t  "

        #expect(!model.canSave)
        await model.save()
        #expect(await repository.stored.isEmpty)
    }

    @Test("a saved thought is stamped with the injected clock, not the system clock")
    func saveUsesInjectedClock() async {
        let (model, repository) = makeModel()
        model.text = "rent splitting app"

        await model.save()

        let stored = await repository.stored
        #expect(stored.count == 1)
        #expect(stored.first?.capturedAt == epoch)
        #expect(stored.first?.state == .inbox)
        #expect(stored.first?.kind == .unsorted)
    }

    @Test("the field clears after a successful save, ready for the next thought")
    func successClearsTheField() async {
        let (model, _) = makeModel()
        model.text = "call the dentist"

        await model.save()

        #expect(model.text.isEmpty)
        #expect(model.lastError == nil)
        #expect(!model.isSaving)
    }

    @Test("a failed save keeps the text — a typed thought is never lost to an error")
    func failureKeepsTheText() async {
        let (model, _) = makeModel(repository: SpyRepository(failing: StorageFailure()))
        model.text = "the one good idea I had all week"

        await model.save()

        #expect(model.text == "the one good idea I had all week")
        #expect(model.lastError != nil)
        #expect(!model.isSaving)
    }

    @Test("only the outer whitespace is trimmed; what was typed inside is preserved")
    func innerTextIsUntouched() async {
        let (model, repository) = makeModel()
        model.text = "\n  line one\n  line two  \n "

        await model.save()

        #expect(await repository.stored.first?.body == "line one\n  line two")
    }

    @Test("saving an empty field does nothing at all")
    func savingNothingIsANoOp() async {
        let (model, repository) = makeModel()

        await model.save()

        #expect(await repository.stored.isEmpty)
        #expect(model.lastError == nil)
    }
}
