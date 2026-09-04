@testable import CaptureFeature
import Core
import Foundation
import Testing

/// A repository seeded with fixed thoughts, recording what was written back.
private actor FakeRepository: ThoughtRepository {
    private(set) var stored: [Thought]

    init(stored: [Thought]) {
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

    func delete(id _: Thought.ID) async throws {}

    func thought(named body: String) -> Thought? {
        stored.first { $0.body == body }
    }
}

private struct StubClock: WallClock {
    let now: Date
}

private let reference = Date(timeIntervalSince1970: 1_700_000_000)

/// Builds a habit at a known age, optionally already marked, at a chosen cadence.
private func habit(
    _ body: String,
    markedAgo: TimeInterval? = nil,
    streak: Int = 0,
    capturedAgo: TimeInterval = .day,
    state: ThoughtState = .inbox,
    cadence: HabitCadence = .daily
) -> Thought {
    Thought(
        body: body,
        capturedAt: reference.addingTimeInterval(-capturedAgo),
        kind: .habit,
        state: state,
        kindSource: .confirmed,
        streak: markedAgo.map {
            Streak(count: streak, lastMarkedAt: reference.addingTimeInterval(-$0))
        },
        cadence: cadence
    )
}

@MainActor
struct DailyHabitsModelTests {
    @Test("Only live, awake habits reach the home screen")
    func loadsHabitsOnly() async {
        let repository = FakeRepository(stored: [
            habit("stretch"),
            Thought(body: "an idea", capturedAt: reference, kind: .idea),
            Thought(body: "a todo", capturedAt: reference, kind: .todo),
            habit("archived habit", state: .archived(at: reference))
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))

        await model.load()

        #expect(model.habits.map(\.body) == ["stretch"])
        #expect(model.hasHabits)
        #expect(model.hasLoaded)
    }

    @Test("A habit already kept for its period is not shown at all")
    func hidesKeptHabits() async {
        let repository = FakeRepository(stored: [
            habit("already done", markedAgo: 3600, streak: 4, capturedAgo: 10 * .day),
            habit("still due", capturedAgo: 5 * .day)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))

        await model.load()

        #expect(model.habits.map(\.body) == ["still due"])
    }

    @Test("A weekly habit kept yesterday is not due again today")
    func respectsALongerCadence() async {
        let repository = FakeRepository(stored: [
            habit("read a chapter", markedAgo: .day, streak: 2, cadence: .weekly),
            habit("stretch", markedAgo: .day, streak: 2, cadence: .daily)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))

        await model.load()

        // The daily one came round again overnight; the weekly one has six days left to run.
        #expect(model.habits.map(\.body) == ["stretch"])
    }

    @Test("A weekly habit kept eight days ago is due again")
    func aLapsedWeeklyHabitReturns() async {
        let repository = FakeRepository(stored: [
            habit("read a chapter", markedAgo: 8 * .day, streak: 2, cadence: .weekly)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))

        await model.load()

        #expect(model.habits.map(\.body) == ["read a chapter"])
    }

    @Test("Marking a habit takes it off the home screen and writes the streak back")
    func marksKept() async {
        let repository = FakeRepository(stored: [
            habit("stretch", markedAgo: 1.5 * .day, streak: 3)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))
        await model.load()

        await model.markKept(model.habits[0])

        // The point of the whole change: it is gone from the screen the instant it is kept.
        #expect(model.habits.isEmpty)
        #expect(!model.hasHabits)
        #expect(model.markedCount == 1)
        let stored = await repository.thought(named: "stretch")
        #expect(stored?.streak?.count == 4)
    }

    @Test("A weekly habit's mark advances its run by one week, not one day")
    func marksAWeeklyHabit() async {
        let repository = FakeRepository(stored: [
            habit("read a chapter", markedAgo: 8 * .day, streak: 2, cadence: .weekly)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))
        await model.load()

        await model.markKept(model.habits[0])

        let stored = await repository.thought(named: "read a chapter")
        #expect(stored?.streak?.count == 3)
    }

    @Test("A habit that is not due cannot be marked, so a run cannot be inflated")
    func refusesToMarkAHabitThatIsNotDue() async {
        let kept = habit("stretch", markedAgo: 3600, streak: 3)
        let repository = FakeRepository(stored: [kept])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))
        await model.load()

        #expect(model.habits.isEmpty)
        // Marking one that never reached the screen, as a stale tap would.
        await model.markKept(kept)

        #expect(model.markedCount == 0)
        let stored = await repository.thought(named: "stretch")
        #expect(stored?.streak?.count == 3)
    }

    @Test("A store with no habits leaves the home screen empty")
    func staysEmptyWithoutHabits() async {
        let repository = FakeRepository(stored: [
            Thought(body: "an idea", capturedAt: reference, kind: .idea)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))

        await model.load()

        #expect(!model.hasHabits)
        #expect(model.hasLoaded)
    }
}

@MainActor
struct CaptureFocusTests {
    @Test("Each request reads as a separate event")
    func countsRequests() {
        let focus = CaptureFocus()
        #expect(focus.requests == 0)

        focus.request()
        focus.request()

        #expect(focus.requests == 2)
    }

    @Test("Only the ambient surfaces' own URL asks for the field")
    func recognisesTheCaptureURL() throws {
        #expect(try CaptureFocus.isCaptureRequest(#require(URL(string: "fleeting://capture"))))
        #expect(try !CaptureFocus.isCaptureRequest(#require(URL(string: "fleeting://review"))))
        #expect(try !CaptureFocus.isCaptureRequest(#require(URL(string: "https://example.com/capture"))))
    }
}
