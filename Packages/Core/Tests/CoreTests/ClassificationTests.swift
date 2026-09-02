@testable import Core
import Foundation
import Testing

@Suite("Kind provenance")
struct KindProvenanceTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("a fresh capture has not been classified")
    func startsUnclassified() {
        let thought = Thought(body: "raw", capturedAt: epoch)
        #expect(thought.kindSource == .unclassified)
        #expect(thought.kind == .unsorted)
    }

    @Test("classification sets the kind and marks it as a guess")
    func classificationIsInferred() {
        var thought = Thought(body: "call the dentist", capturedAt: epoch)
        thought.applyClassification(kind: .todo, title: "Call the dentist")

        #expect(thought.kind == .todo)
        #expect(thought.kindSource == .inferred)
        #expect(thought.title == "Call the dentist")
    }

    @Test("classification never resets decay — the app noticing is not the user attending")
    func classificationDoesNotResetFreshness() {
        var thought = Thought(body: "aging", capturedAt: epoch)
        thought.applyClassification(kind: .idea, title: "Aging")

        #expect(thought.lastActedAt == epoch)
    }

    @Test("classification never touches the raw captured text")
    func classificationLeavesBodyAlone() {
        var thought = Thought(body: "idk something w/ rent??", capturedAt: epoch)
        thought.applyClassification(kind: .idea, title: "Fair rent splitting")

        #expect(thought.body == "idk something w/ rent??")
    }

    @Test("a human correction is remembered and never overwritten by the classifier")
    func confirmedKindSurvivesReclassification() {
        var thought = Thought(body: "call the dentist every month", capturedAt: epoch)
        thought.applyClassification(kind: .habit, title: nil)
        thought.confirmKind(.todo, at: epoch.addingTimeInterval(60))

        thought.applyClassification(kind: .habit, title: "Dentist habit")

        #expect(thought.kind == .todo)
        #expect(thought.kindSource == .confirmed)
        #expect(thought.title == nil, "a rejected classification must not leave its title behind")
    }

    @Test("correcting the kind counts as deliberate action")
    func confirmingResetsFreshness() {
        var thought = Thought(body: "aging", capturedAt: epoch)
        let later = epoch.addingTimeInterval(10 * .day)
        thought.confirmKind(.idea, at: later)

        #expect(thought.lastActedAt == later)
    }

    @Test("an empty generated title is ignored rather than stored")
    func emptyTitleIsIgnored() {
        var thought = Thought(body: "something", capturedAt: epoch)
        thought.applyClassification(kind: .idea, title: "")

        #expect(thought.title == nil)
    }
}

@Suite("Per-kind decay")
struct PerKindDecayTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    private let engine = DecayEngine()

    private func thought(_ kind: ThoughtKind) -> Thought {
        var subject = Thought(body: "a thought", capturedAt: epoch)
        subject.applyClassification(kind: kind, title: nil)
        return subject
    }

    @Test(
        "each kind expires on its own schedule",
        arguments: [
            (ThoughtKind.habit, 7.0), (.todo, 14.0), (.unsorted, 30.0), (.idea, 90.0)
        ]
    )
    func lifetimes(kind: ThoughtKind, days: Double) {
        let subject = thought(kind)
        #expect(engine.expiryDate(of: subject) == epoch.addingTimeInterval(days * .day))
    }

    @Test("a todo ignored for a fortnight is dead while an idea is barely touched")
    func todosDieFasterThanIdeas() {
        let fortnight = epoch.addingTimeInterval(14 * .day)

        #expect(engine.shouldArchive(thought(.todo), at: fortnight))
        #expect(!engine.shouldArchive(thought(.idea), at: fortnight))
        #expect(engine.freshness(of: thought(.idea), at: fortnight).value > 0.9)
    }

    @Test("reclassifying a thought immediately changes when it expires")
    func kindChangeMovesExpiry() {
        var subject = thought(.todo)
        #expect(engine.expiryDate(of: subject) == epoch.addingTimeInterval(14 * .day))

        subject.confirmKind(.idea, at: epoch)
        #expect(engine.expiryDate(of: subject) == epoch.addingTimeInterval(90 * .day))
    }
}

@Suite("Streak")
struct StreakTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("the first mark starts a run of one")
    func firstMark() {
        var streak = Streak()
        streak.mark(at: epoch)
        #expect(streak.count == 1)
    }

    @Test("marking twice in a day changes nothing")
    func sameDayIsIdempotent() {
        var streak = Streak()
        streak.mark(at: epoch)
        streak.mark(at: epoch.addingTimeInterval(3600))
        #expect(streak.count == 1)
    }

    @Test("consecutive days extend the run")
    func consecutiveDaysExtend() {
        var streak = Streak()
        for day in 0 ..< 5 {
            streak.mark(at: epoch.addingTimeInterval(Double(day) * 1.1 * .day))
        }
        #expect(streak.count == 5)
    }

    @Test("a missed day starts the run again")
    func gapResets() {
        var streak = Streak()
        streak.mark(at: epoch)
        streak.mark(at: epoch.addingTimeInterval(1.1 * .day))
        streak.mark(at: epoch.addingTimeInterval(5 * .day))
        #expect(streak.count == 1)
    }

    @Test("undoing a mark takes the run back one")
    func undoTakesBackOne() {
        var streak = Streak()
        streak.mark(at: epoch)
        let second = epoch.addingTimeInterval(1.1 * .day)
        streak.mark(at: second)
        #expect(streak.count == 2)

        streak.unmark(previous: epoch)
        #expect(streak.count == 1)
        #expect(streak.lastMarkedAt == epoch)
    }

    @Test("undoing the only mark leaves the habit untouched")
    func undoingTheOnlyMarkClearsTheDate() {
        var streak = Streak()
        streak.mark(at: epoch)

        streak.unmark()
        #expect(!streak.hasStarted)
        // The date has to go too, or the next mark would see a gap and the habit would look
        // like it had been kept and broken rather than never started.
        #expect(streak.lastMarkedAt == nil)
    }

    @Test("undoing a run that never started does nothing")
    func undoOnEmptyIsSafe() {
        var streak = Streak()
        streak.unmark()
        #expect(!streak.hasStarted)
        #expect(streak.lastMarkedAt == nil)
    }

    @Test("undo then mark again returns the same count")
    func undoIsReversible() {
        var streak = Streak()
        streak.mark(at: epoch)
        streak.unmark()
        streak.mark(at: epoch)
        #expect(streak.count == 1)
    }

    @Test("marking a habit counts as deliberate action and restores freshness")
    func markingIsAnAction() {
        var thought = Thought(body: "stretch every morning", capturedAt: epoch)
        thought.applyClassification(kind: .habit, title: nil)
        let later = epoch.addingTimeInterval(3 * .day)

        thought.markHabitKept(at: later)

        #expect(thought.streak?.count == 1)
        #expect(DecayEngine().freshness(of: thought, at: later) == .full)
    }

    @Test("completing a todo takes it out of play without destroying it")
    func completingATodo() {
        var thought = Thought(body: "call the dentist", capturedAt: epoch)
        thought.complete(at: epoch.addingTimeInterval(60))

        #expect(!thought.state.isLive)
        #expect(thought.state == .done(at: epoch.addingTimeInterval(60)))
    }
}
