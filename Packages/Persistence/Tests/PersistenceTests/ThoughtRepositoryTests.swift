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
            let flattened = StoredState.components(of: state)
            #expect(StoredState.state(raw: flattened.raw, date: flattened.date) == state)
        }
    }

    @Test("an unreadable row loses its lifecycle position, never the thought")
    func corruptRowDegradesToInbox() {
        #expect(StoredState.state(raw: "nonsense", date: nil) == .inbox)
        #expect(StoredState.state(raw: "archived", date: nil) == .inbox)
    }
}
