import Core
import Foundation
@testable import SharpenFeature
import Testing

@MainActor
@Suite("SharpenModel")
struct SharpenModelTests {
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

    @Test("starting asks the model what it needs to know")
    func startGeneratesQuestions() async {
        let (model, _) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?", "What's hard?"])
        )

        await model.start()

        #expect(model.phase == .interviewing)
        #expect(model.progress.total == 2)
        #expect(model.currentQuestion?.prompt == "Who?")
    }

    @Test("a model with nothing to ask fails legibly rather than silently")
    func noQuestionsFailsLegibly() async {
        let (model, _) = makeModel(thought: idea(), intelligence: StubIntelligence(questions: []))

        await model.start()

        guard case let .failed(message) = model.phase else {
            Issue.record("expected a failure phase")
            return
        }
        #expect(message.contains("untouched"))
    }

    @Test("every answer is written to storage as it is given")
    func answersPersistImmediately() async {
        let (model, repository) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?", "What's hard?"])
        )
        await model.start()

        model.draftAnswer = "student houses"
        await model.submitAnswer()

        let stored = await repository.stored.first
        #expect(stored?.sharpening?.answeredCount == 1)
        #expect(stored?.sharpening?.answers.first?.answer == "student houses")
    }

    @Test("an interrupted interview resumes exactly where it stopped")
    func interviewResumes() async throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?", "What's hard?"], at: epoch)
        let first = try #require(thought.sharpening?.questions[0])
        thought.answerSharpening("student houses", to: first.id, at: epoch)

        let (model, _) = makeModel(
            thought: thought,
            intelligence: StubIntelligence(questions: ["should not be asked for"])
        )
        await model.start()

        #expect(model.phase == .interviewing)
        #expect(model.currentQuestion?.prompt == "What's hard?")
        #expect(model.progress == (answered: 1, total: 2))
    }

    @Test("a finished interview reopens showing its write-up, not the questions again")
    func finishedInterviewReopensAtTheResult() async throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?"], at: epoch)
        let question = try #require(thought.sharpening?.questions[0])
        thought.answerSharpening("student houses", to: question.id, at: epoch)
        thought.attachWriteUp(writeUp(), at: epoch)

        let (model, _) = makeModel(thought: thought, intelligence: StubIntelligence())
        await model.start()

        #expect(model.phase == .finished)
        #expect(model.writeUp?.title == "A fair rent calculator")
    }

    @Test("answering the last question produces the write-up automatically")
    func lastAnswerTriggersTheWriteUp() async {
        let (model, repository) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?"], generated: writeUp())
        )
        await model.start()

        model.draftAnswer = "student houses"
        await model.submitAnswer()

        #expect(model.phase == .finished)
        #expect(model.writeUp?.detail.contains("student houses") == true)
        #expect(await repository.stored.first?.sharpening?.writeUp != nil)
    }

    @Test("a failed write-up keeps every answer so nothing has to be retyped")
    func failedWriteUpKeepsAnswers() async {
        let (model, repository) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?"], generated: nil)
        )
        await model.start()

        model.draftAnswer = "student houses"
        await model.submitAnswer()

        guard case .failed = model.phase else {
            Issue.record("expected a failure phase")
            return
        }
        #expect(await repository.stored.first?.sharpening?.answeredCount == 1)
    }

    @Test("blank answers are refused rather than stored")
    func blankAnswersAreRefused() async {
        let (model, repository) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?"])
        )
        await model.start()
        let updatesAfterStart = await repository.updateCount

        model.draftAnswer = "   \n "
        #expect(!model.canSubmit)
        await model.submitAnswer()

        #expect(await repository.updateCount == updatesAfterStart)
        #expect(model.currentQuestion?.prompt == "Who?")
    }

    @Test("the escalation prompt carries the raw note and every answer")
    func escalationPromptIsSelfContained() async throws {
        let (model, _) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?"], generated: writeUp())
        )
        await model.start()
        model.draftAnswer = "student houses"
        await model.submitAnswer()

        let prompt = try #require(model.escalationPrompt)
        #expect(prompt.contains("app for splitting rent fairly"))
        #expect(prompt.contains("student houses"))
        #expect(prompt.contains("A fair rent calculator"))
    }

    @Test("the screen says plainly when it is running on rules rather than a model")
    func degradedStateIsReported() async {
        let (model, _) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(
                questions: ["Who?"],
                reported: .heuristic(reason: .modelDisabled)
            )
        )

        await model.start()

        #expect(model.availability == .heuristic(reason: .modelDisabled))
    }

    @Test("a storage failure is reported and the note is left alone")
    func storageFailureIsReported() async {
        let (model, _) = makeModel(
            thought: idea(),
            intelligence: StubIntelligence(questions: ["Who?"]),
            repository: SpyRepository(failsUpdate: true)
        )

        await model.start()

        guard case let .failed(message) = model.phase else {
            Issue.record("expected a failure phase")
            return
        }
        #expect(message.contains("untouched"))
    }
}
