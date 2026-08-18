import Core
import Foundation
@testable import InboxFeature
import Testing

/// Storage that can be inspected and told to fail.
private actor SpyRepository: ThoughtRepository {
    /// Which operations should fail. Scoped per operation so a test can fail exactly the call
    /// it is about without breaking its own setup.
    struct Failures: OptionSet {
        let rawValue: Int
        static let load = Failures(rawValue: 1 << 0)
        static let update = Failures(rawValue: 1 << 1)
        static let delete = Failures(rawValue: 1 << 2)
    }

    private(set) var thoughts: [Thought]
    private(set) var deletedIDs: [Thought.ID] = []
    private let failures: Failures

    init(_ thoughts: [Thought] = [], failing failures: Failures = []) {
        self.thoughts = thoughts
        self.failures = failures
    }

    func add(_ thought: Thought) async throws {
        thoughts.append(thought)
    }

    func all() async throws -> [Thought] {
        if failures.contains(.load) {
            throw StorageFailure()
        }
        return thoughts.sorted { $0.capturedAt > $1.capturedAt }
    }

    func update(_ thought: Thought) async throws {
        if failures.contains(.update) {
            throw StorageFailure()
        }
        guard let index = thoughts.firstIndex(where: { $0.id == thought.id }) else { return }
        thoughts[index] = thought
    }

    func delete(id: Thought.ID) async throws {
        if failures.contains(.delete) {
            throw StorageFailure()
        }
        deletedIDs.append(id)
        thoughts.removeAll { $0.id == id }
    }
}

private struct StubClock: WallClock {
    let now: Date
}

private struct StorageFailure: Error {}

@MainActor
@Suite("InboxModel")
struct InboxModelTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func thought(_ body: String, offsetDays: Double = 0) -> Thought {
        Thought(body: body, capturedAt: epoch.addingTimeInterval(offsetDays * 86400))
    }

    private func makeModel(
        _ repository: SpyRepository,
        at now: Date? = nil
    ) -> InboxModel {
        InboxModel(repository: repository, clock: StubClock(now: now ?? epoch))
    }

    @Test("an unread inbox is not the same as an empty one")
    func hasLoadedDistinguishesEmptyFromUnread() async {
        let model = makeModel(SpyRepository())
        #expect(!model.hasLoaded)

        await model.load()

        #expect(model.hasLoaded)
        #expect(model.thoughts.isEmpty)
    }

    @Test("thoughts load newest first")
    func loadOrdersNewestFirst() async {
        let repository = SpyRepository([thought("older"), thought("newer", offsetDays: 1)])
        let model = makeModel(repository)

        await model.load()

        #expect(model.thoughts.map(\.body) == ["newer", "older"])
    }

    @Test("a failed load surfaces the error and still marks the inbox as read")
    func loadFailureIsReported() async {
        let model = makeModel(SpyRepository(failing: .load))

        await model.load()

        #expect(model.lastError != nil)
        #expect(model.hasLoaded)
    }

    @Test("deleting removes the thought from storage and from the list")
    func deleteRemovesEverywhere() async {
        let doomed = thought("delete me")
        let repository = SpyRepository([doomed, thought("keep me", offsetDays: 1)])
        let model = makeModel(repository)
        await model.load()

        await model.delete(doomed)

        #expect(model.thoughts.map(\.body) == ["keep me"])
        #expect(await repository.deletedIDs == [doomed.id])
    }

    @Test("a failed delete leaves the thought in the list rather than lying about it")
    func failedDeleteKeepsTheRow() async {
        let doomed = thought("delete me")
        let model = makeModel(SpyRepository([doomed], failing: .delete))
        await model.load()
        model.lastError = nil

        await model.delete(doomed)

        #expect(model.thoughts.count == 1)
        #expect(model.lastError != nil)
    }

    @Test("revising the text counts as deliberate action and restores freshness")
    func reviseResetsFreshness() async {
        let original = thought("somthing about coffee")
        let repository = SpyRepository([original])
        let later = epoch.addingTimeInterval(30 * 86400)
        let model = makeModel(repository, at: later)
        await model.load()

        await model.revise(original, to: "rank coffee shops by outlet count")

        let revised = try? #require(model.thoughts.first)
        #expect(revised?.body == "rank coffee shops by outlet count")
        #expect(revised?.lastActedAt == later)
        #expect(revised?.capturedAt == epoch)
    }

    @Test("a revision that would empty a thought is refused — deletion must be explicit")
    func revisingToNothingIsRefused() async {
        let original = thought("the one good idea")
        let repository = SpyRepository([original])
        let model = makeModel(repository)
        await model.load()

        await model.revise(original, to: "   \n  ")

        #expect(model.thoughts.first?.body == "the one good idea")
        #expect(await repository.thoughts.first?.body == "the one good idea")
    }

    @Test("a revision that changes nothing does not touch freshness")
    func unchangedRevisionIsANoOp() async {
        let original = thought("unchanged")
        let model = makeModel(SpyRepository([original]), at: epoch.addingTimeInterval(9 * 86400))
        await model.load()

        await model.revise(original, to: "unchanged")

        #expect(model.thoughts.first?.lastActedAt == epoch)
    }
}
