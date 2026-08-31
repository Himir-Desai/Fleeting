import Core
import Foundation
@testable import SettingsFeature
import Testing

@MainActor
@Suite("SettingsModel")
struct SettingsModelTests {
    private func makeModel(
        preferences: MemoryPreferences = MemoryPreferences(),
        permissions: SpyPermissions = SpyPermissions(),
        refreshes: RefreshCounter = RefreshCounter(),
        intelligence: StubIntelligence = StubIntelligence(),
        sorting: MemorySorting = MemorySorting(),
        decay: MemoryDecay = MemoryDecay()
    ) -> SettingsModel {
        SettingsModel(
            intelligence: intelligence,
            sortingStore: sorting,
            decayStore: decay,
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
        #expect(!model.canConfigureNudges, "denied means the switches stay hidden")
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

    @Test("settings reports what is actually sorting thoughts, not what was asked for")
    func intelligenceRealityIsHonest() async {
        let onDevice = makeModel(intelligence: StubIntelligence(reported: .onDevice))
        await onDevice.load()
        #expect(onDevice.sortingReality.contains("this iPhone's model"))

        let rules = makeModel(
            intelligence: StubIntelligence(reported: .heuristic(reason: .modelDisabled))
        )
        await rules.load()
        #expect(rules.sortingReality.contains("turned off"))
    }

    @Test("choosing how to sort is saved, and is a choice rather than a failure")
    func sortingIsAChoice() async {
        let sorting = MemorySorting()
        let model = makeModel(
            intelligence: StubIntelligence(reported: .heuristic(reason: .userChose)),
            sorting: sorting
        )
        await model.load()
        #expect(model.sorting == .automatic)

        await model.chooseSorting(.rulesOnly)

        #expect(sorting.stored == .rulesOnly, "a preference nobody stores is a lie")
        #expect(model.sorting == .rulesOnly)
        #expect(model.sortingReality.contains("as you asked"))
    }
}

@MainActor
@Suite("Sync status on the settings screen")
struct SettingsSyncTests {
    private func makeModel(_ status: SyncStatus) -> SettingsModel {
        SettingsModel(
            intelligence: StubIntelligence(),
            sortingStore: MemorySorting(),
            decayStore: MemoryDecay(),
            sync: StubSync(reported: status),
            store: MemoryPreferences(),
            permissions: SpyPermissions(),
            onNudgesChanged: {}
        )
    }

    @Test("the screen says nothing about syncing until it has asked")
    func startsUndecided() {
        #expect(makeModel(.syncing).syncStatus == .checking)
    }

    @Test("a syncing store is described as syncing")
    func syncingReads() async {
        let model = makeModel(.syncing)
        await model.load()
        #expect(model.syncStatus == .syncing)
        #expect(model.facts.first { $0.label == "Syncing" }?.value == "iCloud")
    }

    @Test("a store that is not syncing says so, and says capture still works")
    func localOnlyReads() async {
        var states: [SyncStatus] = [.signedOut]
        states += SyncUnavailableReason.allCases.map { .localOnly($0) }

        for state in states {
            let model = makeModel(state)
            await model.load()
            let fact = model.facts.first { $0.label == "Syncing" }
            #expect(fact?.value == "This iPhone only")
            #expect(fact?.isWarning == true)
        }
    }
}

@MainActor
@Suite("What settings says about storage")
struct SettingsStorageTests {
    private func makeModel(degraded: Bool) -> SettingsModel {
        SettingsModel(
            intelligence: StubIntelligence(),
            sortingStore: MemorySorting(),
            decayStore: MemoryDecay(),
            storageIsDegraded: degraded,
            store: MemoryPreferences(),
            permissions: SpyPermissions(),
            onNudgesChanged: {}
        )
    }

    @Test("a working store is described without alarming anyone")
    func healthyStorageReads() {
        let model = makeModel(degraded: false)
        #expect(model.facts.first { $0.label == "Storage" }?.value == "On this device")
        #expect(model.warning == nil)
    }

    @Test("a store that never opened says so, and says what it costs")
    func degradedStorageReads() {
        let model = makeModel(degraded: true)
        #expect(model.facts.first { $0.label == "Storage" }?.isWarning == true)
        #expect(model.warning?.contains("lost when the app closes") == true)
    }
}
