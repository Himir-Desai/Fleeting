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

    func resurfacingLine(for _: String) async -> String? {
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

extension CaptureModelTests {
    @Test("sharing failures preserve the entire capture draft")
    func sharingFailurePreservesDraft() async {
        let (model, _) = makeModel(repository: SpyRepository(failing: ListSharingError.readOnly))
        model.text = "Private words\nkeep them"
        model.selectedListID = UUID()
        await model.save()
        #expect(model.text == "Private words\nkeep them")
        #expect(model.lastError as? ListSharingError == .readOnly)
        #expect(model.savedCount == 0)
        #expect(!model.isSaving)
    }

    @Test("a capture in a shared list reports manual archiving instead of a misleading expiry")
    func sharedCaptureReceipt() async {
        let list = ThoughtList(name: "Together", defaultKind: .todo, sharing: ListSharing(role: .editor))
        let repository = SpyRepository()
        let model = CaptureModel(
            repository: repository,
            intelligence: StubIntelligence(),
            clock: StubClock(now: epoch),
            listRepository: ListRepository(list)
        )
        await model.loadLists()
        model.selectedListID = list.id
        model.text = "Do together"
        await model.save()
        #expect(model.receipt?.lifetime == "archive manually")
        #expect(await repository.stored.first?.listID == list.id)
    }

    @Test("capture remembers its list and background classification preserves membership")
    func listCapture() async throws {
        let repository = SpyRepository()
        let model = CaptureModel(
            repository: repository,
            intelligence: StubIntelligence(result: Classification(
                kind: .idea,
                title: nil,
                confidence: 0.9
            )),
            clock: StubClock(now: epoch)
        )
        let listID = UUID()
        model.selectedListID = listID
        model.text = "A thought in a list"
        await model.save()
        await model.classificationTask?.value
        #expect(try await repository.all().first?.listID == listID)
        #expect(model.selectedListID == listID)
        #expect(model.text.isEmpty)
    }

    @Test("capture into Plan creates a confirmed dated todo")
    func planCapture() async throws {
        let (model, repository) = makeModel()
        model.selectedListID = ThoughtList.planID
        model.text = "Send draft"
        await model.save()
        let thought = try #require(try await repository.all().first)
        #expect(thought.kind == .todo)
        #expect(thought.kindSource == .confirmed)
        #expect(thought.listID == ThoughtList.planID)
        #expect(try PlanDay(#require(thought.dueAt)) == PlanDay(epoch))
        #expect(model.classificationTask == nil)
    }
}

private actor ListRepository: ThoughtListRepository {
    private var stored: [ThoughtList]
    init(_ list: ThoughtList) {
        stored = [list]
    }

    func lists() async throws -> [ThoughtList] {
        [.plan] + stored
    }

    func saveList(_ list: ThoughtList) async throws {
        stored = [list]
    }

    func deleteList(id: UUID) async throws {
        stored.removeAll { $0.id == id }
    }
}

extension CaptureModelTests {
    @Test("custom list defaults apply at capture, explicit choices override, unsorted still classifies")
    func listDefaults() async throws {
        for kind in ThoughtKind.allCases {
            let list = ThoughtList(name: "Work", defaultKind: kind)
            let repository = SpyRepository()
            let model = CaptureModel(
                repository: repository,
                intelligence: StubIntelligence(result: Classification(
                    kind: .idea,
                    title: nil,
                    confidence: 0.9
                )),
                clock: StubClock(now: epoch),
                listRepository: ListRepository(list)
            )
            await model.loadLists()
            model.selectedListID = list.id
            model.text = "A new thought"
            await model.save()
            await model.classificationTask?.value
            let stored = try #require(await repository.stored.first)
            #expect(stored.listID == list.id)
            #expect(stored.kind == (kind == .unsorted ? .idea : kind))
            #expect(stored.kindSource == (kind == .unsorted ? .inferred : .confirmed))
            #expect(stored.dueAt == nil)
            if kind == .todo {
                #expect(model.receipt?.lifetime == "2 weeks")
            }
            model.chooseKind(.habit)
            model.text = "An explicit choice"
            await model.save()
            #expect(await repository.stored.last?.kind == .habit)
            #expect(await repository.stored.last?.listID == list.id)
        }
    }
}
