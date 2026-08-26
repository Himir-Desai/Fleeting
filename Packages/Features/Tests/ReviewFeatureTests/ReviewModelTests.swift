import Core
import Foundation
@testable import ReviewFeature
import Testing

private actor SpyRepository: ThoughtRepository {
    private(set) var stored: [Thought]

    init(_ stored: [Thought] = []) {
        self.stored = stored
    }

    func add(_ thought: Thought) async throws {
        stored.append(thought)
    }

    func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        stored.filter { scope.contains($0.state) }
    }

    func update(_ thought: Thought) async throws {
        guard let index = stored.firstIndex(where: { $0.id == thought.id }) else { return }
        stored[index] = thought
    }

    func delete(id: Thought.ID) async throws {
        stored.removeAll { $0.id == id }
    }
}

private struct StubClock: WallClock {
    let now: Date
}

private struct StubIntelligence: IntelligenceService {
    var questions: [String] = []
    var availability: IntelligenceAvailability {
        .heuristic(reason: .notBuiltIn)
    }

    func classify(_: String) async -> Classification {
        .unknown
    }

    func interviewQuestions(for _: String) async -> [String] {
        questions
    }

    func writeUp(for _: String, answers _: [AnsweredQuestion], at _: Date) async -> WriteUp? {
        nil
    }

    func resurfacingLine(for _: String) async -> String? {
        nil
    }
}

@MainActor
@Suite("ReviewModel")
struct ReviewModelTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func fading(_ body: String, kind: ThoughtKind = .unsorted, agedDays: Double = 25) -> Thought {
        var thought = Thought(body: body, capturedAt: epoch.addingTimeInterval(-agedDays * .day))
        thought.applyClassification(kind: kind, title: nil)
        return thought
    }

    private func makeModel(
        _ repository: SpyRepository,
        intelligence: StubIntelligence = StubIntelligence()
    ) -> ReviewModel {
        ReviewModel(
            repository: repository,
            intelligence: intelligence,
            clock: StubClock(now: epoch)
        )
    }

    @Test("a session with nothing to decide says so rather than showing an empty stack")
    func emptySession() async {
        let model = makeModel(SpyRepository([Thought(body: "fresh", capturedAt: epoch)]))

        await model.load()

        #expect(model.hasLoaded)
        #expect(model.cards.isEmpty)
        #expect(model.isFinished)
    }

    @Test("the session is capped, so it always has a visible end")
    func sessionIsCapped() async {
        let backlog = (0 ..< 40).map { fading("thought \($0)") }
        let model = makeModel(SpyRepository(backlog))

        await model.load()

        #expect(model.cards.count == 7)
        #expect(model.progress == (position: 1, total: 7))
    }

    @Test("keeping a thought restores its freshness and moves on")
    func keepingAThought() async {
        let repository = SpyRepository([fading("keep me")])
        let model = makeModel(repository)
        await model.load()

        await model.act()

        #expect(model.tally.acted == 1)
        #expect(model.isFinished)
        #expect(await repository.stored.first?.lastActedAt == epoch)
    }

    @Test("snoozing sets a thought aside and counts the deferral")
    func snoozingAThought() async {
        let repository = SpyRepository([fading("later")])
        let model = makeModel(repository)
        await model.load()

        await model.snooze()

        #expect(model.tally.snoozed == 1)
        let stored = await repository.stored.first
        #expect(stored?.state == .snoozed(until: epoch.addingTimeInterval(7 * .day)))
        #expect(stored?.snoozeCount == 1)
    }

    @Test("letting go archives rather than destroys")
    func droppingArchives() async {
        let repository = SpyRepository([fading("let go")])
        let model = makeModel(repository)
        await model.load()

        await model.drop()

        #expect(model.tally.dropped == 1)
        #expect(await repository.stored.count == 1, "nothing may be destroyed by a review")
        #expect(await repository.stored.first?.state == .archived(at: epoch))
    }

    @Test("the session runs to an end and reports what was decided")
    func sessionEndsWithATally() async {
        let repository = SpyRepository([fading("one"), fading("two"), fading("three")])
        let model = makeModel(repository)
        await model.load()

        await model.act()
        await model.snooze()
        await model.drop()

        #expect(model.isFinished)
        #expect(model.tally == ReviewModel.Tally(acted: 1, snoozed: 1, dropped: 1))
        #expect(model.tally.total == 3)
    }

    @Test("the session never grows while it is running")
    func sessionDoesNotGrowMidway() async {
        let repository = SpyRepository([fading("one"), fading("two")])
        let model = makeModel(repository)
        await model.load()
        let dealt = model.cards.count

        try? await repository.add(fading("arrived late"))
        await model.act()

        #expect(model.cards.count == dealt, "a session that grows has no end")
    }

    @Test("only unsharpened ideas carry an ambient question")
    func ambientQuestionOnlyForIdeas() async {
        let repository = SpyRepository([fading("errand", kind: .todo)])
        let model = makeModel(repository, intelligence: StubIntelligence(questions: ["Who?"]))
        await model.load()

        await model.loadAmbientQuestion()

        #expect(!model.currentAcceptsAmbientQuestion)
        #expect(model.ambientQuestion == nil)
    }

    @Test("an idea card carries one question, not the whole interview")
    func ideaCardCarriesOneQuestion() async {
        let repository = SpyRepository([fading("an idea", kind: .idea, agedDays: 60)])
        let model = makeModel(
            repository,
            intelligence: StubIntelligence(questions: ["Who is it for?", "What's hard?"])
        )
        await model.load()

        await model.loadAmbientQuestion()

        #expect(model.ambientQuestion == "Who is it for?")
    }

    @Test("answering the ambient question counts as keeping the thought")
    func answeringCountsAsActing() async {
        let repository = SpyRepository([fading("an idea", kind: .idea, agedDays: 60)])
        let model = makeModel(repository, intelligence: StubIntelligence(questions: ["Who is it for?"]))
        await model.load()
        await model.loadAmbientQuestion()

        model.ambientAnswer = "people who hate suites"
        await model.answerAmbientQuestion()

        #expect(model.tally.acted == 1)
        #expect(model.isFinished)
    }

    @Test("an ambient answer is kept as the start of an interview, not thrown away")
    func ambientAnswerSeedsSharpening() async {
        let repository = SpyRepository([fading("an idea", kind: .idea, agedDays: 60)])
        let model = makeModel(repository, intelligence: StubIntelligence(questions: ["Who is it for?"]))
        await model.load()
        await model.loadAmbientQuestion()

        model.ambientAnswer = "people who hate suites"
        await model.answerAmbientQuestion()

        let stored = await repository.stored.first
        #expect(stored?.sharpening?.questions.first?.prompt == "Who is it for?")
        #expect(stored?.sharpening?.answers.first?.answer == "people who hate suites")
    }

    @Test("a blank ambient answer decides nothing")
    func blankAmbientAnswerIsRefused() async {
        let repository = SpyRepository([fading("an idea", kind: .idea, agedDays: 60)])
        let model = makeModel(repository, intelligence: StubIntelligence(questions: ["Who?"]))
        await model.load()
        await model.loadAmbientQuestion()

        model.ambientAnswer = "   \n "
        await model.answerAmbientQuestion()

        #expect(model.tally.total == 0)
        #expect(!model.isFinished)
    }
}
