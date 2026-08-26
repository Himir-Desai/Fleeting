import Core
import Foundation
@testable import InboxFeature
import Testing

@MainActor
@Suite("InboxModel and decay")
struct InboxDecayTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeModel(
        _ repository: SpyRepository,
        at now: Date,
        sweeper: any ArchiveSweeping = NoopSweeper()
    ) -> InboxModel {
        InboxModel(repository: repository, sweeper: sweeper, clock: StubClock(now: now))
    }

    @Test("archived thoughts never appear in the inbox")
    func archivedAreHidden() async {
        let repository = SpyRepository([
            Thought(body: "live", capturedAt: epoch),
            Thought(body: "gone", capturedAt: epoch, state: .archived(at: epoch))
        ])
        let model = makeModel(repository, at: epoch)

        await model.load()

        #expect(model.thoughts.map(\.body) == ["live"])
    }

    @Test("the inbox reports freshness that matches the engine")
    func freshnessIsExposed() async {
        let repository = SpyRepository([Thought(body: "aging", capturedAt: epoch)])
        let model = makeModel(repository, at: epoch.addingTimeInterval(16 * .day))
        await model.load()

        let subject = model.thoughts[0]
        #expect(abs(model.freshness(of: subject).value - 0.5) < 0.0001)
        #expect(model.expiryDate(of: subject) == epoch.addingTimeInterval(30 * .day))
    }

    @Test("snoozing takes a thought out of the live list and buys it time")
    func snoozeRemovesAndExtends() async {
        let original = Thought(body: "later", capturedAt: epoch)
        let repository = SpyRepository([original])
        let now = epoch.addingTimeInterval(10 * .day)
        let model = makeModel(repository, at: now)
        await model.load()

        await model.snooze(original, forDays: 7)

        #expect(model.thoughts.isEmpty)
        let stored = await repository.thoughts.first
        #expect(stored?.state == .snoozed(until: now.addingTimeInterval(7 * .day)))
        #expect(stored?.lastActedAt == now)
    }

    @Test("archiving by hand removes the thought without destroying it")
    func manualArchiveKeepsTheThought() async {
        let original = Thought(body: "done with this", capturedAt: epoch)
        let repository = SpyRepository([original])
        let model = makeModel(repository, at: epoch)
        await model.load()

        await model.archive(original)

        #expect(model.thoughts.isEmpty)
        #expect(await repository.thoughts.count == 1)
        #expect(await repository.thoughts.first?.state == .archived(at: epoch))
    }

    @Test("loading sweeps first, so an expired thought is gone before the list is drawn")
    func loadSweepsFirst() async {
        let repository = SpyRepository([Thought(body: "expired", capturedAt: epoch)])
        let now = epoch.addingTimeInterval(40 * .day)
        let sweeper = RecordingSweeper(repository: repository, now: now)
        let model = makeModel(repository, at: now, sweeper: sweeper)

        await model.load()

        #expect(await sweeper.didSweep)
        #expect(model.thoughts.isEmpty)
    }

    @Test("a sweeper failure is reported rather than swallowed")
    func sweepFailureSurfaces() async {
        let model = makeModel(SpyRepository(), at: epoch, sweeper: FailingSweeper())

        await model.load()

        #expect(model.lastError != nil)
        #expect(model.hasLoaded)
    }
}

@MainActor
@Suite("InboxModel and kinds")
struct InboxKindTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeModel(_ repository: SpyRepository, at now: Date? = nil) -> InboxModel {
        InboxModel(
            repository: repository,
            sweeper: NoopSweeper(),
            clock: StubClock(now: now ?? epoch)
        )
    }

    private func inferred(_ body: String, as kind: ThoughtKind) -> Thought {
        var thought = Thought(body: body, capturedAt: epoch)
        thought.applyClassification(kind: kind, title: nil)
        return thought
    }

    @Test("correcting a kind is remembered so the classifier cannot undo it")
    func correctionIsConfirmed() async {
        let thought = inferred("call mum every sunday", as: .habit)
        let repository = SpyRepository([thought])
        let model = makeModel(repository)
        await model.load()

        await model.confirmKind(.todo, for: thought)

        let stored = await repository.thoughts.first
        #expect(stored?.kind == .todo)
        #expect(stored?.kindSource == .confirmed)
        #expect(model.thoughts.first?.kind == .todo)
    }

    @Test("correcting to the kind it already is does nothing")
    func noOpCorrection() async {
        let thought = inferred("an idea", as: .idea)
        let repository = SpyRepository([thought])
        let model = makeModel(repository, at: epoch.addingTimeInterval(5 * .day))
        await model.load()

        await model.confirmKind(.idea, for: thought)

        #expect(await repository.thoughts.first?.kindSource == .inferred)
        #expect(await repository.thoughts.first?.lastActedAt == epoch)
    }

    @Test("correcting a kind immediately changes when the thought expires")
    func correctionChangesDecay() async {
        let thought = inferred("call the dentist", as: .todo)
        let repository = SpyRepository([thought])
        let model = makeModel(repository)
        await model.load()
        #expect(model.expiryDate(of: model.thoughts[0]) == epoch.addingTimeInterval(14 * .day))

        await model.confirmKind(.idea, for: thought)

        #expect(model.expiryDate(of: model.thoughts[0]) == epoch.addingTimeInterval(90 * .day))
    }

    @Test("completing a todo takes it out of the live list without destroying it")
    func completingATodo() async {
        let thought = inferred("call the dentist", as: .todo)
        let repository = SpyRepository([thought])
        let model = makeModel(repository)
        await model.load()

        await model.complete(thought)

        #expect(model.thoughts.isEmpty)
        #expect(await repository.thoughts.count == 1)
        #expect(await repository.thoughts.first?.state == .done(at: epoch))
    }

    @Test("keeping a habit extends its streak and restores its freshness")
    func keepingAHabit() async {
        let thought = inferred("stretch every morning", as: .habit)
        let repository = SpyRepository([thought])
        let later = epoch.addingTimeInterval(3 * .day)
        let model = makeModel(repository, at: later)
        await model.load()

        await model.markHabitKept(thought)

        #expect(model.thoughts.first?.streak?.count == 1)
        #expect(model.freshness(of: model.thoughts[0]) == .full)
    }
}
