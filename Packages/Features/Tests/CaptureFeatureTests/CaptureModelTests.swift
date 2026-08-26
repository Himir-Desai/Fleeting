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

    func update(_ thought: Thought) async throws {
        guard let index = stored.firstIndex(where: { $0.id == thought.id }) else { return }
        stored[index] = thought
    }

    func delete(id: Thought.ID) async throws {}
}

private struct StubClock: WallClock {
    let now: Date
}

private struct StorageFailure: Error {}

/// A classifier that answers with a fixed result, optionally slowly.
private struct StubIntelligence: IntelligenceService {
    var result: Classification = .unknown
    var delay: Duration?

    var availability: IntelligenceAvailability {
        .heuristic(reason: .notBuiltIn)
    }

    func classify(_: String) async -> Classification {
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return result
    }

    func interviewQuestions(for _: String) async -> [String] {
        []
    }

    func writeUp(
        for _: String,
        answers _: [AnsweredQuestion],
        at _: Date
    ) async -> WriteUp? {
        nil
    }
}

@MainActor
@Suite("CaptureModel")
struct CaptureModelTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeModel(
        repository: SpyRepository = SpyRepository(),
        intelligence: StubIntelligence = StubIntelligence()
    ) -> (CaptureModel, SpyRepository) {
        let model = CaptureModel(
            repository: repository,
            intelligence: intelligence,
            clock: StubClock(now: epoch)
        )
        return (model, repository)
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

@MainActor
@Suite("Capture and classification")
struct CaptureClassificationTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeModel(
        _ intelligence: StubIntelligence
    ) -> (CaptureModel, SpyRepository) {
        let repository = SpyRepository()
        let model = CaptureModel(
            repository: repository,
            intelligence: intelligence,
            clock: StubClock(now: epoch)
        )
        return (model, repository)
    }

    @Test("a slow classifier never delays the save or the next thought")
    func classificationDoesNotBlockSaving() async {
        let slow = StubIntelligence(
            result: Classification(kind: .todo, title: "Slow", confidence: 0.9),
            delay: .seconds(30)
        )
        let (model, repository) = makeModel(slow)
        model.text = "call the dentist"

        await model.save()

        // save() has returned even though the classifier is still running.
        #expect(model.text.isEmpty)
        #expect(await repository.stored.count == 1)
        #expect(model.classificationTask != nil)
        model.classificationTask?.cancel()
    }

    @Test("a classified thought is updated in storage after the save")
    func classificationIsWrittenBack() async {
        let (model, repository) = makeModel(
            StubIntelligence(result: Classification(kind: .todo, title: "Dentist", confidence: 0.8))
        )
        model.text = "call the dentist"

        await model.save()
        await model.classificationTask?.value

        let stored = await repository.stored.first
        #expect(stored?.kind == .todo)
        #expect(stored?.kindSource == .inferred)
        #expect(stored?.title == "Dentist")
        #expect(stored?.body == "call the dentist", "classification must not touch the raw text")
    }

    @Test("a classifier that decides nothing leaves the thought unsorted rather than guessing")
    func unknownClassificationLeavesItAlone() async {
        let (model, repository) = makeModel(StubIntelligence(result: .unknown))
        model.text = "the light in the kitchen"

        await model.save()
        await model.classificationTask?.value

        let stored = await repository.stored.first
        #expect(stored?.kind == .unsorted)
        #expect(stored?.kindSource == .unclassified)
    }
}
