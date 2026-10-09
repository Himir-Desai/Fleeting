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
    @Test("view-only review permits personal decisions but refuses shared archive and sharpening")
    func viewOnlyReview() async {
        let thought = Thought(
            body: "Shared idea",
            capturedAt: epoch,
            kind: .idea,
            snoozeCount: 3,
            sharing: ListSharing(role: .viewer)
        )
        let repository = SpyRepository([thought])
        let model = makeModel(repository, intelligence: StubIntelligence(questions: ["Who?"]))
        await model.load()
        await model.loadAmbientQuestion()
        #expect(!model.currentAcceptsAmbientQuestion)
        #expect(model.ambientQuestion == nil)
        await model.archive()
        #expect(model.tally.total == 0)
        #expect(model.current?.id == thought.id)
        #expect(await repository.stored.first?.state == .inbox)
        await model.snooze()
        #expect(model.tally.snoozed == 1)
        #expect(model.isFinished)
    }

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

    @Test("remote deletions remove pending cards without resetting completed decisions")
    func cloudReviewChanges() async throws {
        let repository = SpyRepository([fading("first"), fading("second"), fading("third")])
        let model = makeModel(repository)
        await model.load()
        await model.act()
        let pending = try #require(model.current)
        try await repository.delete(id: pending.id)
        await model.refreshPending()
        #expect(model.tally.acted == 1)
        #expect(model.current?.id != pending.id)
        #expect(model.cards.count == 2)
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

        await model.archive()

        #expect(model.tally.archived == 1)
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
        await model.archive()

        #expect(model.isFinished)
        #expect(model.tally == ReviewModel.Tally(acted: 1, snoozed: 1, archived: 1))
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

    @Test("a decision on a later card preserves the current card and its draft answer")
    func laterCardDecision() async throws {
        let first = fading("First")
        let second = fading("Second")
        let third = fading("Third")
        let repository = SpyRepository([first, second, third])
        let model = makeModel(repository)
        await model.load()
        let current = try #require(model.current)
        let later = try #require(model.pendingCards.last)
        model.ambientAnswer = "Keep this draft"
        await model.archive(id: later.id)
        #expect(model.current?.id == current.id)
        #expect(model.pendingCards.count == 2)
        #expect(model.pendingCards.allSatisfy { $0.id != later.id })
        #expect(model.tally.archived == 1)
        #expect(model.ambientAnswer == "Keep this draft")
        let stored = try #require(await repository.stored.first { $0.id == later.id })
        #expect(stored.state == .archived(at: epoch))
        await model.archive(id: later.id)
        #expect(model.tally.archived == 1)
    }

    @Test("a failed review decision preserves the card, answer and tally for retry")
    func failedDecisionKeepsCard() async {
        let thought = fading("Keep me available")
        let model = ReviewModel(
            repository: FailedReviewRepository(thought: thought),
            intelligence: StubIntelligence(),
            clock: StubClock(now: epoch)
        )
        await model.load()
        model.ambientAnswer = "A draft answer"
        await model.act()
        #expect(model.current?.id == thought.id)
        #expect(model.position == 0)
        #expect(model.tally.total == 0)
        #expect(model.ambientAnswer == "A draft answer")
        #expect(model.lastError != nil)
        #expect(!model.isDeciding)
    }
}

private struct ReviewWriteFailure: Error {}

private actor FailedReviewRepository: ThoughtRepository {
    let thought: Thought
    init(thought: Thought) {
        self.thought = thought
    }

    func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        [thought]
    }

    func add(_ thought: Thought) async throws {}
    func update(_ thought: Thought) async throws {
        throw ReviewWriteFailure()
    }

    func delete(id: Thought.ID) async throws {}
}
