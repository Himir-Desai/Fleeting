import Core
import Foundation
@testable import Persistence
import SwiftData
import Testing

@Suite("SwiftDataThoughtRepository")
struct SwiftDataThoughtRepositoryTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeRepository() throws -> SwiftDataThoughtRepository {
        try SwiftDataThoughtRepository(modelContainer: ModelContainerFactory.inMemory())
    }

    @Test("a captured thought survives a round trip unchanged")
    func roundTrip() async throws {
        let repository = try makeRepository()
        let original = Thought(
            body: "idk something w/ rent + roommates??",
            capturedAt: epoch,
            kind: .idea,
            state: .snoozed(until: epoch.addingTimeInterval(86400)),
            title: "Fair rent splitting"
        )

        try await repository.add(original)
        let stored = try #require(try await repository.all().first)

        #expect(stored == original)
    }

    @Test("thoughts come back newest first")
    func ordering() async throws {
        let repository = try makeRepository()
        let older = Thought(body: "older", capturedAt: epoch)
        let newer = Thought(body: "newer", capturedAt: epoch.addingTimeInterval(60))

        try await repository.add(older)
        try await repository.add(newer)

        #expect(try await repository.all().map(\.body) == ["newer", "older"])
    }

    @Test("acting on a thought persists the new freshness, not the old one")
    func updatePersistsLastActedAt() async throws {
        let repository = try makeRepository()
        var thought = Thought(body: "learn Swift", capturedAt: epoch)
        try await repository.add(thought)

        let later = epoch.addingTimeInterval(21 * 86400)
        thought.markActed(at: later)
        try await repository.update(thought)

        let stored = try #require(try await repository.all().first)
        #expect(stored.lastActedAt == later)
        #expect(stored.timeSinceLastAction(at: later) == 0)
    }

    @Test("updating a thought that was never stored is an error, not a silent insert")
    func updateMissingThrows() async throws {
        let repository = try makeRepository()
        let ghost = Thought(body: "never stored", capturedAt: epoch)

        await #expect(throws: PersistenceError.thoughtNotFound(ghost.id)) {
            try await repository.update(ghost)
        }
        #expect(try await repository.all().isEmpty)
    }

    @Test("deletion is explicit and complete")
    func delete() async throws {
        let repository = try makeRepository()
        let thought = Thought(body: "delete me", capturedAt: epoch)
        try await repository.add(thought)

        try await repository.delete(id: thought.id)

        #expect(try await repository.all().isEmpty)
    }
}

@Suite("StoredState")
struct StoredStateTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("every domain state survives being flattened and rebuilt")
    func everyStateRoundTrips() {
        let states: [ThoughtState] = [
            .inbox, .active, .snoozed(until: epoch), .archived(at: epoch), .done(at: epoch)
        ]

        for state in states {
            #expect(StoredState.state(code: StoredState.code(for: state)) == state)
        }
    }

    @Test("an unreadable row loses its lifecycle position, never the thought")
    func corruptRowDegradesToInbox() {
        #expect(StoredState.state(code: "nonsense") == .inbox)
        #expect(StoredState.state(code: "archived") == .inbox)
        #expect(StoredState.state(code: "archived|not-a-date") == .inbox)
        #expect(StoredState.state(code: "") == .inbox)
    }
}

@Suite("Scoped queries and search")
struct ScopedQueryTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeRepository() throws -> SwiftDataThoughtRepository {
        try SwiftDataThoughtRepository(modelContainer: ModelContainerFactory.inMemory())
    }

    private func seed(_ repository: SwiftDataThoughtRepository) async throws {
        try await repository.add(Thought(body: "live idea about coffee", capturedAt: epoch))
        try await repository.add(
            Thought(body: "snoozed idea", capturedAt: epoch, state: .snoozed(until: epoch))
        )
        try await repository.add(
            Thought(body: "archived idea about coffee", capturedAt: epoch, state: .archived(at: epoch))
        )
    }

    @Test("live excludes archived thoughts")
    func liveScope() async throws {
        let repository = try makeRepository()
        try await seed(repository)

        let live = try await repository.thoughts(in: .live).map(\.body)
        #expect(live.sorted() == ["live idea about coffee", "snoozed idea"])
    }

    @Test("archived returns only what has left play")
    func archivedScope() async throws {
        let repository = try makeRepository()
        try await seed(repository)

        #expect(try await repository.thoughts(in: .archived).map(\.body) == ["archived idea about coffee"])
        #expect(try await repository.thoughts(in: .all).count == 3)
    }

    @Test("search matches raw captured text and respects the scope")
    func searchWithinScope() async throws {
        let repository = try makeRepository()
        try await seed(repository)

        #expect(try await repository.search("coffee", in: .all).count == 2)
        #expect(try await repository.search("coffee", in: .archived).count == 1)
        #expect(try await repository.search("COFFEE", in: .live).count == 1)
        #expect(try await repository.search("nothing here", in: .all).isEmpty)
    }

    @Test("a blank query returns the whole scope rather than nothing")
    func blankQueryReturnsEverything() async throws {
        let repository = try makeRepository()
        try await seed(repository)

        #expect(try await repository.search("   ", in: .live).count == 2)
    }

    @Test("whether a state counts as live is derived from the domain, not hardcoded")
    func livenessTracksTheDomain() {
        let live: [ThoughtState] = [.inbox, .active, .snoozed(until: epoch)]
        let gone: [ThoughtState] = [.archived(at: epoch), .done(at: epoch)]

        for state in live {
            #expect(StoredState.isLive(code: StoredState.code(for: state)))
        }
        for state in gone {
            #expect(!StoredState.isLive(code: StoredState.code(for: state)))
        }
    }
}

@Suite("ArchiveSweeper")
struct ArchiveSweeperTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private struct StubClock: WallClock {
        let now: Date
    }

    @Test("expired thoughts are archived, not deleted")
    func expiredAreArchivedNotDeleted() async throws {
        let repository = InMemoryThoughtRepository(seed: [
            Thought(body: "expired", capturedAt: epoch),
            Thought(body: "still fresh", capturedAt: epoch.addingTimeInterval(29 * .day))
        ])
        let sweeper = ArchiveSweeper(
            repository: repository,
            engine: DecayEngine(),
            clock: StubClock(now: epoch.addingTimeInterval(31 * .day))
        )

        let archived = try await sweeper.sweep()

        #expect(archived.map(\.body) == ["expired"])
        #expect(try await repository.thoughts(in: .live).map(\.body) == ["still fresh"])
        #expect(try await repository.thoughts(in: .all).count == 2, "nothing may be destroyed")
    }

    @Test("sweeping twice archives nothing the second time")
    func sweepIsIdempotent() async throws {
        let repository = InMemoryThoughtRepository(seed: [Thought(body: "expired", capturedAt: epoch)])
        let sweeper = ArchiveSweeper(
            repository: repository,
            engine: DecayEngine(),
            clock: StubClock(now: epoch.addingTimeInterval(40 * .day))
        )

        #expect(try await sweeper.sweep().count == 1)
        #expect(try await sweeper.sweep().isEmpty)
    }

    @Test("a snoozed thought is not swept while its snooze is running")
    func snoozeSurvivesTheSweep() async throws {
        var snoozed = Thought(body: "later", capturedAt: epoch)
        snoozed.snooze(until: epoch.addingTimeInterval(60 * .day), at: epoch)
        let repository = InMemoryThoughtRepository(seed: [snoozed])
        let sweeper = ArchiveSweeper(
            repository: repository,
            engine: DecayEngine(),
            clock: StubClock(now: epoch.addingTimeInterval(50 * .day))
        )

        #expect(try await sweeper.sweep().isEmpty)
    }
}

@Suite("Sharpening storage")
struct SharpeningStorageTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeRepository() throws -> SwiftDataThoughtRepository {
        try SwiftDataThoughtRepository(modelContainer: ModelContainerFactory.inMemory())
    }

    private func sharpenedIdea() -> Thought {
        var thought = Thought(body: "app for splitting rent fairly", capturedAt: epoch)
        thought.applyClassification(kind: .idea, title: nil)
        thought.beginSharpening(prompts: ["Who?", "What's hard?"], at: epoch)
        let questions = thought.sharpening?.questions ?? []
        thought.answerSharpening("student houses", to: questions[0].id, at: epoch)
        return thought
    }

    @Test("a half-finished interview survives a round trip, so nothing has to be retyped")
    func partialInterviewRoundTrips() async throws {
        let repository = try makeRepository()
        let original = sharpenedIdea()

        try await repository.add(original)
        let stored = try #require(try await repository.all().first)

        #expect(stored.sharpening?.questions.count == 2)
        #expect(stored.sharpening?.answeredCount == 1)
        #expect(stored.sharpening?.nextUnanswered?.prompt == "What's hard?")
        #expect(stored == original, "the whole thought must round trip, not merely resemble itself")
    }

    @Test("a finished write-up survives a round trip")
    func writeUpRoundTrips() async throws {
        let repository = try makeRepository()
        var original = sharpenedIdea()
        let questions = original.sharpening?.questions ?? []
        original.answerSharpening("agreeing what fair means", to: questions[1].id, at: epoch)
        original.attachWriteUp(
            WriteUp(
                title: "A fair rent calculator",
                detail: "It is for student houses. Write the formula first.",
                generatedAt: epoch
            ),
            at: epoch
        )

        try await repository.add(original)
        let stored = try #require(try await repository.all().first)

        #expect(stored.sharpening?.writeUp?.title == "A fair rent calculator")
        #expect(stored.sharpening?.writeUp?.generatedAt == epoch)
    }

    @Test("a thought that was never sharpened stores nothing for it")
    func unsharpenedStoresNothing() async throws {
        let repository = try makeRepository()
        try await repository.add(Thought(body: "plain", capturedAt: epoch))

        #expect(try await repository.all().first?.sharpening == nil)
    }

    @Test("unreadable interview data costs the interview, never the thought")
    func corruptSharpeningDegrades() {
        #expect(StoredSharpening.decode("{ not json") == nil)
        #expect(StoredSharpening.decode(nil) == nil)
    }
}
