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
