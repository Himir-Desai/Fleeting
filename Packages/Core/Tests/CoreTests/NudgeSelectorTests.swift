@testable import Core
import Foundation
import Testing

@Suite("NudgeSelector")
struct NudgeSelectorTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    private let selector = NudgeSelector()

    private func thought(_ body: String, agedDays: Double, kind: ThoughtKind = .unsorted) -> Thought {
        var subject = Thought(body: body, capturedAt: epoch.addingTimeInterval(-agedDays * .day))
        subject.applyClassification(kind: kind, title: nil)
        return subject
    }

    @Test("nothing is surfaced from an empty collection")
    func emptyCollection() {
        #expect(selector.forgotten(from: [], at: epoch) == nil)
    }

    @Test("a fresh thought is not forgotten, so nothing is sent")
    func freshIsNotForgotten() {
        #expect(selector.forgotten(from: [thought("new", agedDays: 1)], at: epoch) == nil)
    }

    @Test("the most faded thought is the one worth resurfacing")
    func mostFadedWins() {
        let candidates = [
            thought("barely faded", agedDays: 18),
            thought("nearly gone", agedDays: 28),
            thought("halfway", agedDays: 22)
        ]

        #expect(selector.forgotten(from: candidates, at: epoch)?.body == "nearly gone")
    }

    @Test("only one is ever chosen — a nudge is a reminder, not a digest")
    func onlyOneIsChosen() {
        let candidates = (0 ..< 20).map { thought("thought \($0)", agedDays: 25) }
        #expect(selector.forgotten(from: candidates, at: epoch) != nil)
    }

    @Test("something surfaced recently is passed over")
    func recentlySurfacedIsSkipped() {
        let shown = thought("shown yesterday", agedDays: 28)
        let other = thought("not yet shown", agedDays: 24)

        let chosen = selector.forgotten(
            from: [shown, other],
            at: epoch,
            recentlySurfaced: [shown.id]
        )

        #expect(chosen?.body == "not yet shown")
    }

    @Test("skipping everything recently surfaced means saying nothing")
    func everythingSkippedMeansSilence() {
        let only = thought("shown", agedDays: 28)
        #expect(selector.forgotten(from: [only], at: epoch, recentlySurfaced: [only.id]) == nil)
    }

    @Test("archived thoughts are never resurfaced")
    func archivedIsNeverSurfaced() {
        var archived = thought("gone", agedDays: 28)
        archived.archive(at: epoch)

        #expect(selector.forgotten(from: [archived], at: epoch) == nil)
    }

    @Test("a sleeping thought is left alone")
    func snoozedIsLeftAlone() {
        var snoozed = thought("later", agedDays: 28)
        snoozed.snooze(until: epoch.addingTimeInterval(5 * .day), at: epoch)

        #expect(selector.forgotten(from: [snoozed], at: epoch) == nil)
    }

    @Test("expiry warnings cover only what is genuinely close to archiving")
    func expiringSoonIsNarrow() {
        let candidates = [
            thought("tomorrow", agedDays: 29),
            thought("next week", agedDays: 20),
            thought("also soon", agedDays: 28.5)
        ]

        let expiring = selector.expiringSoon(from: candidates, at: epoch).map(\.body)

        #expect(expiring == ["tomorrow", "also soon"], "soonest first, and only within the window")
    }

    @Test("something already expired is not warned about — it is too late to matter")
    func alreadyExpiredIsNotWarned() {
        let gone = thought("long gone", agedDays: 40)
        #expect(selector.expiringSoon(from: [gone], at: epoch).isEmpty)
    }

    @Test("per-kind lifetimes mean kinds warn on their own schedules")
    func kindsWarnOnTheirOwnSchedule() {
        let todo = thought("errand", agedDays: 13, kind: .todo)
        let idea = thought("idea", agedDays: 13, kind: .idea)

        #expect(selector.expiringSoon(from: [todo, idea], at: epoch).map(\.body) == ["errand"])
    }
}
