import Core
import Foundation
@testable import SettingsFeature
import Testing

private struct StubIntelligence: IntelligenceService {
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

private final class MemoryPreferences: NudgePreferencesStoring, @unchecked Sendable {
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

private final class SpyPermissions: NudgePermissions, @unchecked Sendable {
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

/// Counts how often the app was told to rebuild its notification queue.
private final class RefreshCounter: @unchecked Sendable {
    private(set) var count = 0
    func record() {
        count += 1
    }
}

@MainActor
@Suite("SettingsModel")
struct SettingsModelTests {
    private func makeModel(
        preferences: MemoryPreferences = MemoryPreferences(),
        permissions: SpyPermissions = SpyPermissions(),
        refreshes: RefreshCounter = RefreshCounter(),
        intelligence: StubIntelligence = StubIntelligence()
    ) -> SettingsModel {
        SettingsModel(
            intelligence: intelligence,
            profiles: .standard,
            store: preferences,
            permissions: permissions,
            onNudgesChanged: { refreshes.record() }
        )
    }

    @Test("permission is never requested just by opening settings")
    func openingSettingsDoesNotAsk() async {
        let permissions = SpyPermissions()
        let model = makeModel(permissions: permissions)

        await model.load()

        #expect(permissions.requestCount == 0, "the app must ask only when the user chooses to")
        #expect(model.authorization == .notAsked)
    }

    @Test("the switches are hidden until permission exists")
    func switchesAreGatedOnPermission() async {
        let model = makeModel(permissions: SpyPermissions(.notAsked))
        await model.load()
        #expect(!model.canConfigureNudges)

        let allowed = makeModel(permissions: SpyPermissions(.allowed))
        await allowed.load()
        #expect(allowed.canConfigureNudges)
    }

    @Test("asking, and being refused, is reported honestly rather than hidden")
    func refusalIsReported() async {
        let permissions = SpyPermissions(.notAsked, granting: .denied)
        let model = makeModel(permissions: permissions)
        await model.load()

        await model.requestPermission()

        #expect(model.authorization == .denied)
        #expect(!model.canConfigureNudges)
        #expect(model.notificationStatus.detail.contains("Settings app"))
    }

    @Test("granting permission rebuilds the queue immediately")
    func grantingRefreshesTheQueue() async {
        let refreshes = RefreshCounter()
        let model = makeModel(permissions: SpyPermissions(.notAsked), refreshes: refreshes)
        await model.load()

        await model.requestPermission()

        #expect(refreshes.count == 1)
    }

    @Test("changing a preference is saved and rebuilds the queue")
    func changingAPreferenceSavesAndRefreshes() async {
        let preferences = MemoryPreferences()
        let refreshes = RefreshCounter()
        let model = makeModel(preferences: preferences, refreshes: refreshes)
        await model.load()

        await model.update { $0.dailyEnabled = false }

        #expect(!preferences.stored.dailyEnabled)
        #expect(!model.preferences.dailyEnabled)
        #expect(refreshes.count == 1, "a preference nobody acts on is a lie")
    }

    @Test("the daily hour is clamped rather than accepted blindly")
    func hourIsClamped() {
        #expect(NudgePreferences(dailyHour: 47).dailyHour == 23)
        #expect(NudgePreferences(dailyHour: -3).dailyHour == 0)
        #expect(NudgePreferences(weeklyWeekday: 12).weeklyWeekday == 7)
    }

    @Test("settings reports which implementation is sorting thoughts")
    func intelligenceStatusIsHonest() async {
        let onDevice = makeModel(intelligence: StubIntelligence(reported: .onDevice))
        await onDevice.load()
        #expect(onDevice.status.headline == "On-device model")

        let rules = makeModel(
            intelligence: StubIntelligence(reported: .heuristic(reason: .modelDisabled))
        )
        await rules.load()
        #expect(rules.status.headline == "Rules")
        #expect(rules.status.detail.contains("turned off"))
    }
}
