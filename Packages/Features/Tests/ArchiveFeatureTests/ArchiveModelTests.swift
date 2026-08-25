@testable import ArchiveFeature
import Core
import Foundation
import Testing

private actor SpyRepository: ThoughtRepository {
    private(set) var thoughts: [Thought]
    private(set) var deletedIDs: [Thought.ID] = []

    init(_ thoughts: [Thought] = []) {
        self.thoughts = thoughts
    }

    func add(_ thought: Thought) async throws {
        thoughts.append(thought)
    }

    func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        thoughts.filter { scope.contains($0.state) }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    func update(_ thought: Thought) async throws {
        guard let index = thoughts.firstIndex(where: { $0.id == thought.id }) else { return }
        thoughts[index] = thought
    }

    func delete(id: Thought.ID) async throws {
        deletedIDs.append(id)
        thoughts.removeAll { $0.id == id }
    }
}

private struct StubClock: WallClock {
    let now: Date
}

@MainActor
@Suite("ArchiveModel")
struct ArchiveModelTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func archived(_ body: String) -> Thought {
        Thought(body: body, capturedAt: epoch, state: .archived(at: epoch))
    }

    private func makeModel(_ repository: SpyRepository, at now: Date? = nil) -> ArchiveModel {
        ArchiveModel(repository: repository, clock: StubClock(now: now ?? epoch))
    }

    @Test("the archive shows only what has left play")
    func onlyArchivedAppear() async {
        let repository = SpyRepository([archived("gone"), Thought(body: "live", capturedAt: epoch)])
        let model = makeModel(repository)

        await model.search()

        #expect(model.results.map(\.body) == ["gone"])
    }

    @Test("an empty query returns the whole archive")
    func emptyQueryReturnsEverything() async {
        let model = makeModel(SpyRepository([archived("one"), archived("two")]))

        await model.search()

        #expect(model.results.count == 2)
    }

    @Test("search matches raw captured text, case-insensitively")
    func searchMatchesText() async {
        let model = makeModel(SpyRepository([archived("coffee shops"), archived("rent splitting")]))
        model.query = "COFFEE"

        await model.search()

        #expect(model.results.map(\.body) == ["coffee shops"])
    }

    @Test("restoring returns a thought to the inbox at full freshness")
    func restoreRevives() async throws {
        let thought = archived("rescued")
        let repository = SpyRepository([thought])
        let later = epoch.addingTimeInterval(200 * .day)
        let model = makeModel(repository, at: later)
        await model.search()

        await model.restore(thought)

        #expect(model.results.isEmpty)
        let stored = await repository.thoughts.first
        #expect(stored?.state == .inbox)
        #expect(try DecayEngine().freshness(of: #require(stored), at: later) == .full)
    }

    @Test("deleting from the archive is the only thing that destroys a thought")
    func deleteDestroys() async {
        let thought = archived("really gone")
        let repository = SpyRepository([thought])
        let model = makeModel(repository)
        await model.search()

        await model.delete(thought)

        #expect(await repository.deletedIDs == [thought.id])
        #expect(await repository.thoughts.isEmpty)
    }
}
