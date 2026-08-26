import Core
import Foundation
@testable import Notifications
import Testing

@Suite("NudgeScheduler")
struct NudgeSchedulerTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func fading(_ body: String, agedDays: Double = 25) -> Thought {
        Thought(body: body, capturedAt: epoch.addingTimeInterval(-agedDays * .day))
    }

    private func makeScheduler(
        thoughts: [Thought],
        authorization: NudgeAuthorization = .allowed,
        preferences: NudgePreferences = .standard,
        history: MemoryHistory = MemoryHistory(),
        line: String? = nil
    ) -> (NudgeScheduler, SpyCentre) {
        let centre = SpyCentre()
        let composer = NudgeComposer(
            intelligence: StubIntelligence(line: line),
            times: NudgeClock(calendar: utcCalendar)
        )
        let scheduler = NudgeScheduler(
            repository: MemoryRepository(thoughts),
            composer: composer,
            centre: centre,
            permissions: StubPermissions(state: authorization),
            preferences: MemoryPreferences(preferences),
            history: history,
            clock: StubClock(now: epoch)
        )
        return (scheduler, centre)
    }

    @Test("nothing is queued until permission has been given")
    func noPermissionMeansNoQueue() async {
        let (scheduler, centre) = makeScheduler(
            thoughts: [fading("forgotten")],
            authorization: .notAsked
        )

        let queued = await scheduler.refresh()

        #expect(queued.isEmpty)
        #expect(await centre.queued.isEmpty)
    }

    @Test("turning notifications off clears what was already queued")
    func denialCancelsExistingQueue() async {
        let (scheduler, centre) = makeScheduler(
            thoughts: [fading("forgotten")],
            authorization: .denied
        )

        await scheduler.refresh()

        #expect(await centre.cancelled.contains(NudgeIdentifier.all))
    }

    @Test("a forgotten thought is resurfaced in its own words")
    func dailyUsesTheThought() async {
        let (scheduler, _) = makeScheduler(thoughts: [fading("rank coffee shops by outlets")])

        let queued = await scheduler.refresh()
        let daily = queued.first { $0.kind == .dailyResurface }

        #expect(daily?.body == "rank coffee shops by outlets")
        #expect(daily?.fireAt ?? epoch > epoch)
    }

    @Test("a model's line is preferred over the raw note when one is available")
    func dailyPrefersTheModelLine() async {
        let (scheduler, _) = makeScheduler(
            thoughts: [fading("rank coffee shops by outlets")],
            line: "That coffee shop idea is still sitting here."
        )

        let queued = await scheduler.refresh()

        #expect(
            queued.first { $0.kind == .dailyResurface }?.body
                == "That coffee shop idea is still sitting here."
        )
    }

    @Test("nothing forgotten means no daily nudge, rather than an invented one")
    func nothingForgottenMeansSilence() async {
        let (scheduler, _) = makeScheduler(thoughts: [Thought(body: "fresh", capturedAt: epoch)])

        let queued = await scheduler.refresh()

        #expect(!queued.contains { $0.kind == .dailyResurface })
    }

    @Test("the same thought is not resurfaced two days running")
    func recentlySurfacedIsSkipped() async {
        let thought = fading("already shown")
        let (scheduler, _) = makeScheduler(
            thoughts: [thought],
            history: MemoryHistory([thought.id])
        )

        let queued = await scheduler.refresh()

        #expect(!queued.contains { $0.kind == .dailyResurface })
    }

    @Test("surfacing a thought is remembered so tomorrow picks something else")
    func surfacingIsRecorded() async {
        let thought = fading("shown today")
        let history = MemoryHistory()
        let (scheduler, _) = makeScheduler(thoughts: [thought], history: history)

        await scheduler.refresh()

        #expect(history.recentlySurfaced().contains(thought.id))
    }

    @Test("a review invitation is only sent when something actually needs deciding")
    func weeklyOnlyWhenThereIsWork() async {
        let (withWork, _) = makeScheduler(thoughts: [fading("needs a decision")])
        let (withoutWork, _) = makeScheduler(thoughts: [Thought(body: "fresh", capturedAt: epoch)])

        #expect(await withWork.refresh().contains { $0.kind == .weeklyReview })
        #expect(await !withoutWork.refresh().contains { $0.kind == .weeklyReview })
    }

    @Test("only one expiry warning is sent, for the thought closest to archiving")
    func oneExpiryWarningOnly() async {
        let (scheduler, _) = makeScheduler(
            thoughts: [fading("soonest", agedDays: 29), fading("later", agedDays: 28.5)]
        )

        let queued = await scheduler.refresh()
        let warnings = queued.filter { $0.kind == .expiryWarning }

        #expect(warnings.count == 1)
        #expect(warnings.first?.body == "soonest")
    }

    @Test("preferences switch each kind off independently")
    func preferencesAreHonoured() async {
        let silent = NudgePreferences(
            dailyEnabled: false, weeklyEnabled: false, expiryWarningsEnabled: false
        )
        let (scheduler, _) = makeScheduler(
            thoughts: [fading("forgotten", agedDays: 29)],
            preferences: silent
        )

        #expect(await scheduler.refresh().isEmpty)
    }

    @Test("refreshing replaces the queue rather than adding to it")
    func refreshReplacesRatherThanAccumulates() async {
        let (scheduler, centre) = makeScheduler(thoughts: [fading("forgotten")])

        await scheduler.refresh()
        await scheduler.refresh()

        let identifiers = await centre.queued.map(\.id)
        #expect(identifiers.count == Set(identifiers).count, "a nudge must never be queued twice")
    }

    @Test("the app only ever cancels identifiers it owns")
    func cancellationIsScopedToThisApp() async {
        let (scheduler, centre) = makeScheduler(thoughts: [fading("forgotten")])

        await scheduler.refresh()

        for batch in await centre.cancelled {
            #expect(batch.isSubset(of: NudgeIdentifier.all))
        }
    }
}
