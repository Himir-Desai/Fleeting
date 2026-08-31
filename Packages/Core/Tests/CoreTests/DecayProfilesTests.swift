@testable import Core
import Foundation
import Testing

@Suite("Editable decay rates")
struct EditableDecayProfilesTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("changing a lifetime changes when that kind actually expires")
    func editingChangesDecay() {
        var thought = Thought(body: "buy milk", capturedAt: epoch)
        thought.applyClassification(kind: .todo, title: nil)

        let standard = DecayEngine(profiles: .standard)
        let longer = DecayEngine(profiles: .standard.setting(lifetime: 30 * .day, for: .todo))

        // The point of the setting: the same thought now lives twice as long.
        #expect(standard.expiryDate(of: thought) == epoch.addingTimeInterval(14 * .day))
        #expect(longer.expiryDate(of: thought) == epoch.addingTimeInterval(30 * .day))
    }

    @Test("changing one kind leaves every other kind untouched")
    func editingIsNarrow() {
        let edited = DecayProfiles.standard.setting(lifetime: 60 * .day, for: .todo)

        #expect(edited.policy(for: .todo).lifetime == 60 * .day)
        for kind in [ThoughtKind.idea, .habit, .unsorted] {
            #expect(edited.policy(for: kind) == DecayProfiles.standard.policy(for: kind))
        }
    }

    @Test("shortening a lifetime past its grace clamps rather than inverting decay")
    func graceIsClamped() {
        // Idea ships with 7 days of grace; asking for a 2-day lifetime must not leave grace
        // longer than the lifetime, which would make the decay window negative.
        let edited = DecayProfiles.standard.setting(lifetime: 2 * .day, for: .idea)
        let policy = edited.policy(for: .idea)

        #expect(policy.lifetime == 2 * .day)
        #expect(policy.grace <= policy.lifetime)
    }

    @Test("edited rates survive being stored and read back")
    func profilesRoundTrip() throws {
        let edited = DecayProfiles.standard
            .setting(lifetime: 45 * .day, for: .todo)
            .setting(lifetime: 3 * .day, for: .habit)

        let data = try JSONEncoder().encode(edited)
        let restored = try JSONDecoder().decode(DecayProfiles.self, from: data)

        #expect(restored == edited)
        #expect(!restored.isStandard)
    }

    @Test("the rates the app ships with know they are the defaults")
    func standardIsStandard() {
        #expect(DecayProfiles.standard.isStandard)
        #expect(!DecayProfiles.standard.setting(lifetime: .day, for: .idea).isStandard)
    }

    @Test("an engine reading live rates sees a change without being rebuilt")
    func engineReadsLive() {
        // The reason the engine takes a closure: one engine is shared by every screen, so a
        // change made in Settings has to reach all of them without a relaunch.
        nonisolated(unsafe) var current = DecayProfiles.standard
        let engine = DecayEngine(profiles: { current })

        var thought = Thought(body: "buy milk", capturedAt: epoch)
        thought.applyClassification(kind: .todo, title: nil)
        #expect(engine.expiryDate(of: thought) == epoch.addingTimeInterval(14 * .day))

        current = current.setting(lifetime: 30 * .day, for: .todo)

        #expect(engine.expiryDate(of: thought) == epoch.addingTimeInterval(30 * .day))
    }
}
