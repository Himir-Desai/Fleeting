@testable import Core
import Foundation
import Testing

@Suite("Thought")
struct ThoughtTests {
    @Test("a fresh capture is unsorted, in the inbox, and has no generated title")
    func captureDefaults() {
        let clock = TestClock()
        let thought = Thought(body: "rent splitting app", capturedAt: clock.now)

        #expect(thought.kind == .unsorted)
        #expect(thought.state == .inbox)
        #expect(thought.title == nil)
        #expect(thought.lastActedAt == thought.capturedAt)
    }

    @Test("time passing does not change the thought, only what we ask of it")
    func timeSinceLastAction() {
        let clock = TestClock()
        let thought = Thought(body: "call the dentist", capturedAt: clock.now)

        clock.advance(days: 9)

        #expect(thought.timeSinceLastAction(at: clock.now) == 9 * 86400)
    }

    @Test("acting on a thought restores its freshness")
    func markActedResetsTheClock() {
        let clock = TestClock()
        var thought = Thought(body: "learn Swift", capturedAt: clock.now)

        clock.advance(days: 21)
        thought.markActed(at: clock.now)

        #expect(thought.timeSinceLastAction(at: clock.now) == 0)
    }

    @Test("revising the text counts as deliberate action")
    func reviseIsAnAction() {
        let clock = TestClock()
        var thought = Thought(body: "somthing about coffee", capturedAt: clock.now)

        clock.advance(days: 5)
        thought.revise(body: "rank coffee shops by outlet count", at: clock.now)

        #expect(thought.body == "rank coffee shops by outlet count")
        #expect(thought.timeSinceLastAction(at: clock.now) == 0)
    }

    @Test("a generated title never touches the captured text")
    func generatedTitleLeavesBodyAlone() {
        let clock = TestClock()
        var thought = Thought(body: "idk something w/ rent + roommates??", capturedAt: clock.now)

        thought.title = "Fair rent splitting"

        #expect(thought.body == "idk something w/ rent + roommates??")
    }

    @Test("a thought is never negatively stale, even if the clock moves backwards")
    func clockSkewCannotProduceNegativeStaleness() {
        let clock = TestClock()
        let thought = Thought(body: "captured after a timezone change", capturedAt: clock.now)
        let earlier = clock.now.addingTimeInterval(-3600)

        #expect(thought.timeSinceLastAction(at: earlier) == 0)
    }

    @Test("two thoughts captured with the same text are still distinct")
    func identityIsNotContent() {
        let clock = TestClock()
        let first = Thought(body: "same words", capturedAt: clock.now)
        let second = Thought(body: "same words", capturedAt: clock.now)

        #expect(first != second)
        #expect(first.id != second.id)
    }
}

@Suite("ThoughtState")
struct ThoughtStateTests {
    @Test(
        "live states keep decaying",
        arguments: [ThoughtState.inbox, .active, .snoozed(until: .distantFuture)]
    )
    func liveStates(state: ThoughtState) {
        #expect(state.isLive)
    }

    @Test(
        "terminal states are out of play",
        arguments: [ThoughtState.archived(at: .distantPast), .done(at: .distantPast)]
    )
    func terminalStates(state: ThoughtState) {
        #expect(!state.isLive)
    }

    @Test("archiving records when it happened, so nothing is lost silently")
    func archivedCarriesItsDate() {
        let when = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(ThoughtState.archived(at: when).enteredAt == when)
        #expect(ThoughtState.inbox.enteredAt == nil)
    }
}
