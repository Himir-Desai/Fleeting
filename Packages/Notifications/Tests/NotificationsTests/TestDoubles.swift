import Core
import Foundation
@testable import Notifications

/// A notification centre that records instead of delivering.
actor SpyCentre: NotificationScheduling {
    private(set) var queued: [ScheduledNudge] = []
    private(set) var cancelled: [Set<String>] = []

    func pendingIdentifiers() async -> Set<String> {
        Set(queued.map(\.id))
    }

    func schedule(_ nudge: ScheduledNudge) async {
        queued.removeAll { $0.id == nudge.id }
        queued.append(nudge)
    }

    func cancel(_ identifiers: Set<String>) async {
        cancelled.append(identifiers)
        queued.removeAll { identifiers.contains($0.id) }
    }
}

/// Permission fixed by the test.
struct StubPermissions: NudgePermissions {
    let state: NudgeAuthorization
    var authorization: NudgeAuthorization {
        get async { state }
    }

    func request() async -> NudgeAuthorization {
        state
    }
}

/// Preferences held in memory.
final class MemoryPreferences: NudgePreferencesStoring, @unchecked Sendable {
    private var stored: NudgePreferences
    init(_ stored: NudgePreferences = .standard) {
        self.stored = stored
    }

    func load() -> NudgePreferences {
        stored
    }

    func save(_ preferences: NudgePreferences) {
        stored = preferences
    }
}

/// History held in memory.
final class MemoryHistory: NudgeHistoryStoring, @unchecked Sendable {
    private var ids: [Thought.ID]
    init(_ ids: [Thought.ID] = []) {
        self.ids = ids
    }

    func recentlySurfaced() -> Set<Thought.ID> {
        Set(ids)
    }

    func recordSurfaced(_ id: Thought.ID) {
        ids.append(id)
    }
}

/// Storage held in memory.
actor MemoryRepository: ThoughtRepository {
    private var stored: [Thought]
    init(_ stored: [Thought] = []) {
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

    func delete(id: Thought.ID) async throws {
        stored.removeAll { $0.id == id }
    }
}

/// A clock frozen at a chosen instant.
struct StubClock: WallClock {
    let now: Date
}

/// Intelligence whose resurfacing line is fixed by the test.
struct StubIntelligence: IntelligenceService {
    var line: String?
    var availability: IntelligenceAvailability {
        .heuristic(reason: .notBuiltIn)
    }

    func classify(_: String) async -> Classification {
        .unknown
    }

    func interviewQuestions(for _: String) async -> [String] {
        []
    }

    func writeUp(for _: String, answers _: [AnsweredQuestion], at _: Date) async -> WriteUp? {
        nil
    }

    func resurfacingLine(for _: String) async -> String? {
        line
    }
}

/// A calendar pinned to UTC so scheduling maths does not depend on the machine.
var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}
