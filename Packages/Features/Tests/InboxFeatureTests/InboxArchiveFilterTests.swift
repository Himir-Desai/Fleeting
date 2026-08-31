import Core
import Foundation
@testable import InboxFeature
import Testing

/// The archive as a filter on the one stream rather than a page of its own (ADR-0026).
///
/// These cover what the removed `ArchiveFeature` used to: that archived thoughts are reachable,
/// that restoring revives one at full freshness, and that deleting is the only thing in the app
/// that destroys a thought.
@MainActor
@Suite("InboxModel and the archived filter")
struct InboxArchiveFilterTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeModel(_ repository: SpyRepository, at now: Date) -> InboxModel {
        InboxModel(repository: repository, sweeper: NoopSweeper(), clock: StubClock(now: now))
    }

    private func archived(_ body: String) -> Thought {
        Thought(body: body, capturedAt: epoch, state: .archived(at: epoch))
    }

    @Test("the archived filter shows only what has left play, and never mixes it into All")
    func archivedAreSeparate() async {
        let repository = SpyRepository([Thought(body: "live", capturedAt: epoch), archived("gone")])
        let model = makeModel(repository, at: epoch)

        await model.load()

        #expect(model.filteredThoughts.map(\.body) == ["live"])
        #expect(model.archivedCount == 1)

        model.filter = .archived
        #expect(model.filteredThoughts.map(\.body) == ["gone"])
        #expect(model.isShowingArchive)
    }

    @Test("a kind filter never shows an archived thought of that kind")
    func kindFilterExcludesArchived() async {
        var stale = archived("archived idea")
        stale.applyClassification(kind: .idea, title: nil)
        let repository = SpyRepository([stale])
        let model = makeModel(repository, at: epoch)
        await model.load()

        model.filter = .kind(.idea)

        #expect(model.filteredThoughts.isEmpty)
    }

    @Test("archiving by hand puts the thought under the Archived chip without a reload")
    func archivingUpdatesTheArchivedListImmediately() async {
        let live = Thought(body: "past it", capturedAt: epoch)
        let repository = SpyRepository([live])
        let model = makeModel(repository, at: epoch)
        await model.load()

        await model.archive(live)

        #expect(model.archivedCount == 1)
        model.filter = .archived
        #expect(model.filteredThoughts.map(\.body) == ["past it"])
    }

    @Test("completing a todo does not put it under the Archived chip")
    func completingIsNotArchiving() async {
        var todo = Thought(body: "buy milk", capturedAt: epoch)
        todo.applyClassification(kind: .todo, title: nil)
        let repository = SpyRepository([todo])
        let model = makeModel(repository, at: epoch)
        await model.load()

        await model.complete(todo)

        #expect(model.archivedCount == 0)
    }

    @Test("restoring returns a thought to the inbox at full freshness")
    func restoreRevives() async throws {
        let thought = archived("rescued")
        let repository = SpyRepository([thought])
        let later = epoch.addingTimeInterval(200 * .day)
        let model = makeModel(repository, at: later)
        await model.load()
        model.filter = .archived

        await model.restore(thought)

        #expect(model.filteredThoughts.isEmpty)
        #expect(model.archivedCount == 0)
        let stored = try #require(await repository.thoughts.first)
        #expect(stored.state == .inbox)
        #expect(DecayEngine().freshness(of: stored, at: later) == .full)

        model.filter = .all
        #expect(model.filteredThoughts.map(\.body) == ["rescued"])
    }

    @Test("deleting from the archive is the only thing that destroys a thought")
    func deleteDestroys() async {
        let thought = archived("really gone")
        let repository = SpyRepository([thought])
        let model = makeModel(repository, at: epoch)
        await model.load()
        model.filter = .archived

        await model.delete(thought)

        #expect(await repository.deletedIDs == [thought.id])
        #expect(await repository.thoughts.isEmpty)
        #expect(model.filteredThoughts.isEmpty)
    }
}
