import Core
import Foundation

actor SpyRepository: ThoughtRepository {
    private(set) var stored: [Thought]
    private(set) var updateCount = 0
    private let failsUpdate: Bool

    init(_ stored: [Thought] = [], failsUpdate: Bool = false) {
        self.stored = stored
        self.failsUpdate = failsUpdate
    }

    func add(_ thought: Thought) async throws {
        stored.append(thought)
    }

    func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        stored.filter { scope.contains($0.state) }
    }

    func update(_ thought: Thought) async throws {
        if failsUpdate {
            throw StubError()
        }
        updateCount += 1
        if let index = stored.firstIndex(where: { $0.id == thought.id }) {
            stored[index] = thought
        } else {
            stored.append(thought)
        }
    }

    func delete(id: Thought.ID) async throws {
        stored.removeAll { $0.id == id }
    }
}

struct StubError: Error {}

struct StubClock: WallClock {
    let now: Date
}

/// A classifier whose sharpening answers are fixed by the test.
struct StubIntelligence: IntelligenceService {
    var questions: [String] = []
    var generated: WriteUp?
    var reported: IntelligenceAvailability = .onDevice

    var availability: IntelligenceAvailability {
        reported
    }

    func classify(_: String) async -> Classification {
        .unknown
    }

    func interviewQuestions(for _: String) async -> [String] {
        questions
    }

    func writeUp(for _: String, answers _: [AnsweredQuestion], at _: Date) async -> WriteUp? {
        generated
    }

    func resurfacingLine(for _: String) async -> String? {
        nil
    }
}
