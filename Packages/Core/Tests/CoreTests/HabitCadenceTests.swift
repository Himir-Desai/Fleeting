import Core
import Foundation
import Testing

/// Covers ADR-0048: a habit's cadence decides when it is due, how its run is counted, and who is
/// allowed to change it.
@Suite("Habit cadence")
struct HabitCadenceTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    /// A habit at a chosen cadence, marked a given interval ago.
    private func habit(cadence: HabitCadence, markedAgo: TimeInterval?, count: Int = 1) -> Thought {
        Thought(
            body: "a habit",
            capturedAt: epoch.addingTimeInterval(-30 * .day),
            kind: .habit,
            streak: markedAgo.map {
                Streak(count: count, lastMarkedAt: epoch.addingTimeInterval(-$0))
            },
            cadence: cadence
        )
    }

    @Test("a habit never marked is due")
    func neverMarkedIsDue() {
        #expect(habit(cadence: .daily, markedAgo: nil).isDue(at: epoch))
        #expect(habit(cadence: .monthly, markedAgo: nil).isDue(at: epoch))
    }

    @Test("a habit marked within its period is not due")
    func markedWithinPeriodIsNotDue() {
        #expect(!habit(cadence: .daily, markedAgo: 3600).isDue(at: epoch))
        #expect(!habit(cadence: .weekly, markedAgo: 3 * .day).isDue(at: epoch))
        #expect(!habit(cadence: .monthly, markedAgo: 20 * .day).isDue(at: epoch))
    }

    @Test("a habit becomes due again once its period has elapsed")
    func dueAgainAfterThePeriod() {
        #expect(habit(cadence: .daily, markedAgo: 1.1 * .day).isDue(at: epoch))
        #expect(habit(cadence: .weekly, markedAgo: 8 * .day).isDue(at: epoch))
        #expect(habit(cadence: .fortnightly, markedAgo: 15 * .day).isDue(at: epoch))
    }

    @Test("only habits are ever due")
    func otherKindsAreNeverDue() {
        let todo = Thought(body: "pay the fine", capturedAt: epoch, kind: .todo)
        let idea = Thought(body: "an app that", capturedAt: epoch, kind: .idea)

        #expect(!todo.isDue(at: epoch))
        #expect(!idea.isDue(at: epoch))
    }

    @Test("a weekly run advances once a week, and a second mark the same week does nothing")
    func weeklyRunAdvancesWeekly() {
        var thought = habit(cadence: .weekly, markedAgo: 8 * .day, count: 2)

        thought.markHabitKept(at: epoch)
        #expect(thought.streak?.count == 3)

        // Same week: a second mark must not inflate the run.
        thought.markHabitKept(at: epoch.addingTimeInterval(.day))
        #expect(thought.streak?.count == 3)
    }

    @Test("a run lapses only after two whole periods, whatever the cadence")
    func runLapsesAfterTwoPeriods() {
        var withinGrace = habit(cadence: .weekly, markedAgo: 10 * .day, count: 5)
        withinGrace.markHabitKept(at: epoch)
        #expect(withinGrace.streak?.count == 6, "one missed week does not end a run")

        var lapsed = habit(cadence: .weekly, markedAgo: 20 * .day, count: 5)
        lapsed.markHabitKept(at: epoch)
        #expect(lapsed.streak?.count == 1, "two missed weeks starts a new run")
    }

    @Test("a run is counted in the cadence's own unit")
    func streakUnitFollowsCadence() {
        #expect(HabitCadence.daily.streakUnit(count: 1) == "day")
        #expect(HabitCadence.daily.streakUnit(count: 4) == "days")
        #expect(HabitCadence.weekly.streakUnit(count: 4) == "weeks")
        #expect(HabitCadence.monthly.streakUnit(count: 1) == "month")
        #expect(HabitCadence.fortnightly.streakUnit(count: 2) == "fortnights")
    }

    @Test("a habit with nothing said about frequency is daily")
    func defaultsToDaily() {
        let thought = Thought(body: "stretch", capturedAt: epoch, kind: .habit)

        #expect(thought.cadence == .daily)
        #expect(thought.cadenceSource == .unclassified)
    }

    @Test("a cadence the user chose is never overwritten by classification")
    func chosenCadenceSurvivesClassification() {
        var thought = Thought(body: "read every day", capturedAt: epoch, kind: .habit)
        thought.setCadence(.weekly)

        thought.applyInferredCadence(.daily)

        #expect(thought.cadence == .weekly)
        #expect(thought.cadenceSource == .confirmed)
    }

    @Test("an inferred cadence may be replaced by a later inference")
    func inferredCadenceCanBeRevised() {
        var thought = Thought(body: "read", capturedAt: epoch, kind: .habit)

        thought.applyInferredCadence(.daily)
        #expect(thought.cadenceSource == .inferred)

        thought.applyInferredCadence(.weekly)
        #expect(thought.cadence == .weekly)
    }

    @Test("a habit is never archived before its own cadence brings it round again")
    func decayOutlivesTheCadence() {
        let engine = DecayEngine()

        for cadence in HabitCadence.allCases {
            let thought = Thought(
                body: "a habit",
                capturedAt: epoch,
                kind: .habit,
                cadence: cadence
            )
            let lifetime = engine.policy(for: thought).lifetime

            // The bug this guards: the shipped habit rate is a week, so a monthly habit would
            // have been swept into the archive three weeks before it was ever due again.
            #expect(
                lifetime > cadence.period,
                "\(cadence.label) habit dies after \(lifetime / .day) days"
            )
        }
    }

    @Test("a daily habit keeps the configured rate rather than being shortened")
    func dailyHabitsKeepTheConfiguredRate() {
        let engine = DecayEngine()
        let daily = Thought(body: "stretch", capturedAt: epoch, kind: .habit, cadence: .daily)

        #expect(engine.policy(for: daily).lifetime == 7 * .day)
    }

    @Test("a capture-time lifetime override still wins over the cadence")
    func customLifetimeStillWins() {
        let engine = DecayEngine()
        let thought = Thought(
            body: "a habit",
            capturedAt: epoch,
            kind: .habit,
            cadence: .monthly,
            customLifetime: 3 * .day
        )

        #expect(engine.policy(for: thought).lifetime == 3 * .day)
    }

    @Test("choosing a cadence does not count as keeping the habit")
    func choosingACadenceIsNotAnAction() {
        var thought = habit(cadence: .daily, markedAgo: 2 * .day, count: 3)
        let before = thought.lastActedAt

        thought.setCadence(.weekly)

        #expect(thought.lastActedAt == before, "a setting must not restore freshness")
        #expect(thought.streak?.count == 3, "a setting must not touch the run")
    }
}
