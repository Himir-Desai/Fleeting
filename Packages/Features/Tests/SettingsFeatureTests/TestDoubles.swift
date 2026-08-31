import Core
import Foundation
@testable import SettingsFeature
import Testing

// The stand-ins every settings suite shares: an intelligence that reports whatever it is told,
// and in-memory versions of the four things Settings reads and writes.

struct StubIntelligence: IntelligenceService {
    var reported: IntelligenceAvailability = .onDevice
    var availability: IntelligenceAvailability {
        reported
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
        nil
    }
}

struct StubSync: SyncReporting {
    var reported: SyncStatus
    var status: SyncStatus {
        reported
    }
}

final class MemoryPreferences: NudgePreferencesStoring, @unchecked Sendable {
    private(set) var stored: NudgePreferences
    private(set) var saveCount = 0
    init(_ stored: NudgePreferences = .standard) {
        self.stored = stored
    }

    func load() -> NudgePreferences {
        stored
    }

    func save(_ preferences: NudgePreferences) {
        stored = preferences
        saveCount += 1
    }
}

final class SpyPermissions: NudgePermissions, @unchecked Sendable {
    private(set) var requestCount = 0
    private var state: NudgeAuthorization
    private let granting: NudgeAuthorization

    init(_ state: NudgeAuthorization = .notAsked, granting: NudgeAuthorization = .allowed) {
        self.state = state
        self.granting = granting
    }

    var authorization: NudgeAuthorization {
        get async { state }
    }

    func request() async -> NudgeAuthorization {
        requestCount += 1
        state = granting
        return granting
    }
}

final class MemorySorting: SortingPreferenceStoring, @unchecked Sendable {
    private(set) var stored: SortingPreference
    init(_ stored: SortingPreference = .automatic) {
        self.stored = stored
    }

    func load() -> SortingPreference {
        stored
    }

    func save(_ preference: SortingPreference) {
        stored = preference
    }
}

final class MemoryDecay: DecayProfilesStoring, @unchecked Sendable {
    private(set) var stored: DecayProfiles
    private(set) var saveCount = 0
    init(_ stored: DecayProfiles = .standard) {
        self.stored = stored
    }

    func load() -> DecayProfiles {
        stored
    }

    func save(_ profiles: DecayProfiles) {
        stored = profiles
        saveCount += 1
    }
}

/// Counts how often the app was told to rebuild its notification queue.
final class RefreshCounter: @unchecked Sendable {
    private(set) var count = 0
    func record() {
        count += 1
    }
}
