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

/// Builds a habit at a known age, optionally already marked.
private func habit(
    _ body: String,
    markedAgo: TimeInterval? = nil,
    streak: Int = 0,
    capturedAgo: TimeInterval = .day,
    state: ThoughtState = .inbox
) -> Thought {
    Thought(
        body: body,
        capturedAt: reference.addingTimeInterval(-capturedAgo),
        kind: .habit,
        state: state,
        kindSource: .confirmed,
        streak: markedAgo.map {
            Streak(count: streak, lastMarkedAt: reference.addingTimeInterval(-$0))
        }
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

    @Test("Habits still due today are listed before ones already kept")
    func ordersDueFirst() async {
        let repository = FakeRepository(stored: [
            habit("already done", markedAgo: 3600, streak: 4, capturedAgo: 10 * .day),
            habit("still due", capturedAgo: 5 * .day)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))

        await model.load()

        #expect(model.habits.map(\.body) == ["still due", "already done"])
    }

    @Test("A mark extends the streak and is written back")
    func marksKept() async {
        let repository = FakeRepository(stored: [
            habit("stretch", markedAgo: 1.5 * .day, streak: 3)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))
        await model.load()

        await model.markKept(model.habits[0])

        #expect(model.streakCount(of: model.habits[0]) == 4)
        #expect(model.isKeptToday(model.habits[0]))
        #expect(model.markedCount == 1)
        let stored = await repository.thought(named: "stretch")
        #expect(stored?.streak?.count == 4)
    }

    @Test("A habit already kept today cannot be marked again")
    func refusesASecondMark() async {
        let repository = FakeRepository(stored: [
            habit("stretch", markedAgo: 3600, streak: 3)
        ])
        let model = DailyHabitsModel(repository: repository, clock: StubClock(now: reference))
        await model.load()

        #expect(model.isKeptToday(model.habits[0]))
        await model.markKept(model.habits[0])

        #expect(model.streakCount(of: model.habits[0]) == 3)
        #expect(model.markedCount == 0)
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
