import Core
import Foundation
@testable import SettingsFeature
import Testing

/// The decay rates as a setting rather than a readout.
///
/// The rates are the app's central rule, so being able to change them is the app's central
/// setting (ADR-0031). These cover the model; that a changed rate actually moves an expiry date
/// is covered in `CoreTests`.
@MainActor
@Suite("Editing how long things last")
struct SettingsLifetimeTests {
    private func makeModel(decay: MemoryDecay = MemoryDecay()) -> SettingsModel {
        SettingsModel(
            intelligence: StubIntelligence(),
            sortingStore: MemorySorting(),
            decayStore: decay,
            store: MemoryPreferences(),
            permissions: SpyPermissions(),
            onNudgesChanged: {}
        )
    }

    @Test("a lifetime can be changed, and is stored in days")
    func lifetimeIsEditable() async {
        let decay = MemoryDecay()
        let model = makeModel(decay: decay)
        await model.load()

        model.setLifetime(days: 30, for: .todo)

        #expect(decay.stored.policy(for: .todo).lifetime == 30 * .day)
        #expect(model.lifetimes.first { $0.kind == .todo }?.days == 30)
        #expect(model.lifetimesAreCustom)
    }

    @Test("a lifetime can never be set to zero, which would archive on capture")
    func lifetimeHasAFloor() async {
        let decay = MemoryDecay()
        let model = makeModel(decay: decay)
        await model.load()

        model.setLifetime(days: 0, for: .idea)

        #expect(decay.stored.policy(for: .idea).lifetime == .day)
    }

    @Test("changing a lifetime leaves the other kinds alone")
    func editingOneKindIsNotEditingAll() async {
        let model = makeModel()
        await model.load()
        let ideaBefore = model.lifetimes.first { $0.kind == .idea }?.days

        model.setLifetime(days: 3, for: .habit)

        #expect(model.lifetimes.first { $0.kind == .idea }?.days == ideaBefore)
    }

    @Test("the rates can be put back, and stop reading as custom")
    func lifetimesCanBeReset() async {
        let decay = MemoryDecay()
        let model = makeModel(decay: decay)
        await model.load()
        model.setLifetime(days: 99, for: .todo)
        #expect(model.lifetimesAreCustom)

        model.resetLifetimes()

        #expect(!model.lifetimesAreCustom)
        #expect(decay.stored == .standard)
    }
}
