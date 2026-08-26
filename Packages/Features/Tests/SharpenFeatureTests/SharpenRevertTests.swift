import Core
import Foundation
@testable import SharpenFeature
import Testing

@MainActor
@Suite("SharpenModel revert")
struct SharpenRevertTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func idea() -> Thought {
        var thought = Thought(body: "app for splitting rent fairly", capturedAt: epoch)
        thought.applyClassification(kind: .idea, title: nil)
        return thought
    }

    private func writeUp() -> WriteUp {
        WriteUp(
            title: "A fair rent calculator",
            detail: "It is for student houses. Sketch the formula first.",
            generatedAt: epoch
        )
    }

    private func makeModel(
        thought: Thought,
        intelligence: StubIntelligence,
        repository: SpyRepository = SpyRepository()
    ) -> (SharpenModel, SpyRepository) {
        let model = SharpenModel(
            thought: thought,
            repository: repository,
            intelligence: intelligence,
            clock: StubClock(now: epoch)
        )
        return (model, repository)
    }

    @Test("reverting removes the interview and the write-up together")
    func revertClearsEverything() async {
        let (model, repository) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?"], generated: writeUp())
        )
        await model.start()
        model.draftAnswer = "student houses"
        await model.submitAnswer()
        #expect(model.canRevert)

        let reverted = await model.revert()

        #expect(reverted)
        #expect(model.writeUp == nil)
        #expect(!model.canRevert)
        #expect(await repository.stored.first?.sharpening == nil)
    }

    @Test("reverting never touches the captured text")
    func revertKeepsTheNote() async {
        let (model, repository) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?"], generated: writeUp())
        )
        await model.start()
        model.draftAnswer = "student houses"
        await model.submitAnswer()

        _ = await model.revert()

        #expect(await repository.stored.first?.body == "app for splitting rent fairly")
    }

    @Test("there is nothing to revert before an interview has begun")
    func nothingToRevertAtFirst() {
        let (model, _) = makeModel(thought: idea(), intelligence: StubIntelligence())
        #expect(!model.canRevert)
    }

    @Test("a failed revert leaves the write-up in place rather than half-removing it")
    func failedRevertKeepsTheWriteUp() async throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?"], at: epoch)
        let question = try #require(thought.sharpening?.questions[0])
        thought.answerSharpening("student houses", to: question.id, at: epoch)
        thought.attachWriteUp(writeUp(), at: epoch)

        let (model, _) = makeModel(
            thought: thought,
            intelligence: StubIntelligence(),
            repository: SpyRepository(failsUpdate: true)
        )
        await model.start()

        let reverted = await model.revert()

        #expect(!reverted)
        guard case .failed = model.phase else {
            Issue.record("expected a failure phase")
            return
        }
    }
}
