@testable import Core
import Foundation
import Testing

@Suite("ReviewSelector")
struct ReviewSelectorTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    private let selector = ReviewSelector()

    /// A thought of the given kind, captured a given number of days ago.
    private func thought(
        _ body: String,
        kind: ThoughtKind = .unsorted,
        agedDays: Double,
        snoozes: Int = 0
    ) -> Thought {
        var subject = Thought(
            body: body,
            capturedAt: epoch.addingTimeInterval(-agedDays * .day),
            snoozeCount: snoozes
        )
        subject.applyClassification(kind: kind, title: nil)
        return subject
    }

    @Test("an empty collection produces an empty session")
    func emptyBacklog() {
        #expect(selector.select(from: [], at: epoch).isEmpty)
    }

    @Test("fresh thoughts are left alone — a review of things that are fine is noise")
    func freshThoughtsAreNotRaised() {
        let fresh = [thought("just captured", agedDays: 1), thought("still new", agedDays: 3)]
        #expect(selector.select(from: fresh, at: epoch).isEmpty)
    }

    @Test("a fading thought needs a decision")
    func fadingThoughtIsRaised() {
        let fading = thought("half gone", agedDays: 20)
        #expect(selector.select(from: [fading], at: epoch).map(\.body) == ["half gone"])
    }

    @Test("the session is hard-capped, however large the backlog")
    func sessionIsCapped() {
        let backlog = (0 ..< 300).map { thought("thought \($0)", agedDays: 25) }
        #expect(selector.select(from: backlog, at: epoch).count == 7)
    }

    @Test("hundreds of thoughts still select in a predictable order")
    func largeBacklogIsOrdered() {
        let backlog = (0 ..< 200).map { thought("thought \($0)", agedDays: Double(20 + $0 % 8)) }
        let session = selector.select(from: backlog, at: epoch)

        #expect(session.count == 7)
        let ages = session.map { epoch.timeIntervalSince($0.capturedAt) }
        #expect(ages == ages.sorted(by: >), "the most decayed must come first")
    }

    @Test("archived and completed thoughts never appear")
    func terminalStatesAreExcluded() {
        var archived = thought("archived", agedDays: 25)
        archived.archive(at: epoch)
        var done = thought("done", agedDays: 25)
        done.complete(at: epoch)

        #expect(selector.select(from: [archived, done], at: epoch).isEmpty)
    }

    @Test("a thought still inside its snooze is left asleep")
    func runningSnoozeIsRespected() {
        var snoozed = thought("later", agedDays: 25)
        snoozed.snooze(until: epoch.addingTimeInterval(3 * .day), at: epoch)

        #expect(selector.select(from: [snoozed], at: epoch).isEmpty)
    }

    @Test("a snooze buys real time: a thought is fresh again the moment it wakes")
    func wakingFromSnoozeIsFresh() {
        var snoozed = thought("later", agedDays: 40)
        snoozed.snooze(until: epoch.addingTimeInterval(-1 * .day), at: epoch.addingTimeInterval(-8 * .day))

        #expect(
            selector.select(from: [snoozed], at: epoch).isEmpty,
            "decay restarts from the end of the snooze, so waking up does not mean expiring"
        )
    }

    @Test("a thought that woke long ago decays again and returns to the review")
    func longAwakeThoughtReturns() {
        var snoozed = thought("later", agedDays: 60)
        snoozed.snooze(until: epoch.addingTimeInterval(-20 * .day), at: epoch.addingTimeInterval(-30 * .day))

        #expect(selector.select(from: [snoozed], at: epoch).map(\.body) == ["later"])
    }

    @Test("something snoozed repeatedly is raised even while it is still fresh")
    func repeatedSnoozingIsItsOwnSignal() {
        let deferred = thought("keeps getting put off", agedDays: 1, snoozes: 3)
        #expect(selector.select(from: [deferred], at: epoch).map(\.body) == ["keeps getting put off"])
    }

    @Test("a much-deferred thought does not crowd out things about to be lost")
    func urgencyBalancesDecayAgainstDeferral() {
        let deferred = thought("deferred", agedDays: 1, snoozes: 9)
        let expiring = thought("expiring", agedDays: 29)

        #expect(selector.select(from: [deferred, expiring], at: epoch).first?.body == "expiring")
    }

    @Test("per-kind decay means kinds surface on their own schedules")
    func kindsSurfaceOnTheirOwnSchedule() {
        let todo = thought("errand", kind: .todo, agedDays: 10)
        let idea = thought("idea", kind: .idea, agedDays: 10)

        let session = selector.select(from: [todo, idea], at: epoch)

        #expect(session.map(\.body) == ["errand"], "a 10-day-old todo is fading; an idea is not")
    }

    @Test("ties are broken by age, so the oldest is dealt with first")
    func tiesBreakByAge() {
        let older = thought("older", agedDays: 25)
        let newer = thought("newer", agedDays: 25)
        let backlog = [newer, older]

        // Same freshness, so the earlier capture must lead.
        let session = selector.select(from: backlog, at: epoch)
        #expect(session.first?.capturedAt == min(older.capturedAt, newer.capturedAt))
    }

    @Test("counting agrees with selecting")
    func countMatchesSelection() {
        let backlog = (0 ..< 40).map { thought("thought \($0)", agedDays: 25) }
        #expect(selector.count(from: backlog, at: epoch) == selector.select(from: backlog, at: epoch).count)
    }

    @Test("a limit of zero yields no session at all")
    func zeroLimit() {
        let empty = ReviewSelector(limit: 0)
        #expect(empty.select(from: [thought("fading", agedDays: 25)], at: epoch).isEmpty)
    }
}
