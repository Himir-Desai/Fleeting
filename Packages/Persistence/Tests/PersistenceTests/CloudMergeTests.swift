import Core
import Foundation
@testable import Persistence
import Testing

/// CloudKit merges a record column by column, so a row can end up holding one device's value for
/// one column and another device's value for the next. These tests pin what that can and cannot
/// do to a thought (ADR-0019).
@Suite("Merging two devices")
struct CloudMergeTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    /// Every pairing of two lifecycle positions two devices could disagree about.
    private var disagreements: [(ThoughtState, ThoughtState)] {
        let states: [ThoughtState] = [
            .inbox,
            .active,
            .snoozed(until: epoch.addingTimeInterval(3 * .day)),
            .archived(at: epoch.addingTimeInterval(9 * .day)),
            .done(at: epoch.addingTimeInterval(11 * .day))
        ]
        return states.flatMap { first in states.map { (first, $0) } }
    }

    @Test("version 1's separate columns could merge into a state neither device was ever in")
    func separateColumnsTear() {
        let onePhone = ThoughtState.snoozed(until: epoch.addingTimeInterval(3 * .day))
        let theOther = ThoughtState.archived(at: epoch.addingTimeInterval(9 * .day))

        let position = StoredState.components(of: onePhone)
        let date = StoredState.components(of: theOther)
        let merged = StoredState.state(code: StoredState.code(raw: position.raw, date: date.date))

        #expect(merged == .snoozed(until: epoch.addingTimeInterval(9 * .day)))
        #expect(merged != onePhone)
        #expect(merged != theOther)
    }

    @Test("one column can only ever merge into a position one of the two devices held")
    func combinedColumnCannotTear() {
        for (onePhone, theOther) in disagreements {
            for winner in [StoredState.code(for: onePhone), StoredState.code(for: theOther)] {
                let merged = StoredState.state(code: winner)
                #expect(merged == onePhone || merged == theOther)
            }
        }
    }

    @Test("a streak can only ever merge into a run one of the two devices actually had")
    func streakCannotTear() {
        let runs = [
            Streak(count: 3, lastMarkedAt: epoch),
            Streak(count: 7, lastMarkedAt: epoch.addingTimeInterval(4 * .day)),
            Streak(count: 1, lastMarkedAt: nil)
        ]

        for onePhone in runs {
            for theOther in runs {
                for winner in [StoredStreak.code(for: onePhone), StoredStreak.code(for: theOther)] {
                    let merged = StoredStreak.streak(code: winner)
                    #expect(merged == onePhone || merged == theOther)
                }
            }
        }
    }

    @Test("a torn liveness flag misplaces a thought in a list but never changes what it is")
    func tornLivenessIsRecoverable() {
        var thought = Thought(body: "learn to sail", capturedAt: epoch)
        thought.archive(at: epoch.addingTimeInterval(9 * .day))
        let row = ThoughtEntity(thought)

        // As if the derived flag arrived from a device that still had the thought in play.
        row.isLive = true

        #expect(row.domain.state == thought.state)
        row.overwrite(with: row.domain)
        #expect(row.isLive == false)
    }

    @Test("a snooze made on both devices at once is counted once, never lost")
    func concurrentSnoozesConverge() {
        let thought = Thought(body: "call the landlord", capturedAt: epoch)
        var onePhone = thought
        var theOther = thought
        onePhone.snooze(until: epoch.addingTimeInterval(2 * .day), at: epoch)
        theOther.snooze(until: epoch.addingTimeInterval(5 * .day), at: epoch)

        // Counting is not a union: two simultaneous snoozes read as one. Accepted, because the
        // count only nudges a thought up the review order (ADR-0019).
        for winner in [onePhone, theOther] {
            #expect(winner.snoozeCount == thought.snoozeCount + 1)
        }
    }

    @Test("captured text is whichever device wrote last, never a blend of the two")
    func contentIsLastWriterWins() {
        var onePhone = Thought(body: "rent split idea", capturedAt: epoch)
        var theOther = onePhone
        onePhone.revise(body: "rent split idea — per room, not per head", at: epoch)
        theOther.revise(body: "rent split idea — weight by income", at: epoch)

        for winner in [onePhone, theOther] {
            let merged = ThoughtEntity(winner).domain
            #expect(merged.body == onePhone.body || merged.body == theOther.body)
        }
    }
}
