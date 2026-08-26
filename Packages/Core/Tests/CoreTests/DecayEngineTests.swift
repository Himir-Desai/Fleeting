@testable import Core
import Foundation
import Testing

@Suite("DecayEngine")
struct DecayEngineTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    private let engine = DecayEngine()

    private func thought(state: ThoughtState = .inbox) -> Thought {
        Thought(body: "a thought", capturedAt: epoch, state: state)
    }

    private func day(_ count: Double) -> Date {
        epoch.addingTimeInterval(count * .day)
    }

    @Test("a thought is fully fresh the moment it is captured")
    func freshAtCapture() {
        #expect(engine.freshness(of: thought(), at: epoch) == .full)
    }

    @Test("grace holds new captures at full freshness so the list does not start dying at once")
    func graceHoldsFullFreshness() {
        #expect(engine.freshness(of: thought(), at: day(1.9)) == .full)
    }

    @Test("decay begins once grace has run out")
    func decayBeginsAfterGrace() {
        let justAfterGrace = engine.freshness(of: thought(), at: day(2.1))
        #expect(justAfterGrace < .full)
        #expect(justAfterGrace.value > 0.9)
    }

    @Test("freshness falls to exactly half at the midpoint of the decay window")
    func halfwayIsHalfFresh() {
        // grace 2d, lifetime 30d, so the window is 28d and its midpoint is day 16.
        let midpoint = engine.freshness(of: thought(), at: day(16))
        #expect(abs(midpoint.value - 0.5) < 0.0001)
    }

    @Test("a thought expires exactly at the end of its lifetime")
    func expiresAtLifetime() {
        #expect(!engine.freshness(of: thought(), at: day(29.9)).hasExpired)
        #expect(engine.freshness(of: thought(), at: day(30)).hasExpired)
    }

    @Test("freshness never goes negative, however long it is left")
    func neverNegative() {
        #expect(engine.freshness(of: thought(), at: day(4000)) == .expired)
    }

    @Test("acting on a thought restores it to full freshness")
    func actingRestoresFreshness() {
        var subject = thought()
        subject.markActed(at: day(20))

        #expect(engine.freshness(of: subject, at: day(20)) == .full)
        #expect(engine.expiryDate(of: subject) == day(50))
    }

    @Test("merely viewing a thought does nothing — this is the failure mode of every other app")
    func viewingDoesNotResetDecay() {
        let subject = thought()
        _ = engine.freshness(of: subject, at: day(10))
        _ = engine.freshness(of: subject, at: day(15))

        #expect(engine.freshness(of: subject, at: day(20)) == engine.freshness(of: subject, at: day(20)))
        #expect(engine.freshness(of: subject, at: day(20)).value < 0.4)
    }

    @Test("a snoozed thought is held at full freshness until the snooze ends")
    func snoozePausesDecay() {
        var subject = thought()
        subject.snooze(until: day(40), at: day(10))

        #expect(engine.freshness(of: subject, at: day(39)) == .full)
        #expect(engine.freshness(of: subject, at: day(41)) == .full)
        #expect(engine.freshness(of: subject, at: day(60)).value < 1)
        #expect(engine.expiryDate(of: subject) == day(70))
    }

    @Test("archived and completed thoughts stop decaying entirely")
    func terminalStatesDoNotDecay() {
        for state in [ThoughtState.archived(at: epoch), .done(at: epoch)] {
            let subject = thought(state: state)
            #expect(engine.freshness(of: subject, at: day(1)) == .expired)
            #expect(engine.expiryDate(of: subject) == nil)
            #expect(!engine.shouldArchive(subject, at: day(999)))
        }
    }

    @Test("only live thoughts that have run out are swept into the archive")
    func shouldArchiveOnlyExpiredLiveThoughts() {
        #expect(!engine.shouldArchive(thought(), at: day(29)))
        #expect(engine.shouldArchive(thought(), at: day(30)))
    }

    @Test("bands move fresh, settling, fading, expiring as time passes")
    func bandsProgress() {
        let bands = [1, 12, 22, 29].map { engine.freshness(of: thought(), at: day(Double($0))).band }
        #expect(bands == [.fresh, .settling, .fading, .expiring])
    }

    @Test("a policy with no decay window still expires at its lifetime")
    func degeneratePolicyIsSafe() {
        let flat = FreshnessPolicy(grace: 10 * .day, lifetime: 10 * .day)
        let cliff = DecayEngine(profiles: DecayProfiles(policies: [:], fallback: flat))
        #expect(cliff.freshness(of: thought(), at: day(9)) == .full)
        #expect(cliff.freshness(of: thought(), at: day(10)) == .expired)
    }

    @Test("grace longer than lifetime is clamped rather than producing nonsense")
    func graceIsClamped() {
        let policy = FreshnessPolicy(grace: 100 * .day, lifetime: 10 * .day)
        #expect(policy.grace == 10 * .day)
        #expect(policy.decayWindow == 0)
    }
}

@Suite("Freshness")
struct FreshnessTests {
    @Test("values are clamped into 0...1", arguments: [(-5.0, 0.0), (0.5, 0.5), (7.0, 1.0)])
    func clamping(raw: Double, expected: Double) {
        #expect(Freshness(raw).value == expected)
    }

    @Test("freshness is ordered, so a list can be sorted by how alive things are")
    func ordering() {
        #expect(Freshness(0.2) < Freshness(0.8))
        #expect([Freshness(0.9), Freshness(0.1)].min() == Freshness(0.1))
    }
}

@Suite("ThoughtScope")
struct ThoughtScopeTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("live excludes what has left play")
    func liveScope() {
        #expect(ThoughtScope.live.contains(.inbox))
        #expect(ThoughtScope.live.contains(.snoozed(until: epoch)))
        #expect(!ThoughtScope.live.contains(.archived(at: epoch)))
    }

    @Test("archived is the complement of live, and all is everything")
    func otherScopes() {
        #expect(ThoughtScope.archived.contains(.done(at: epoch)))
        #expect(!ThoughtScope.archived.contains(.active))
        #expect(ThoughtScope.all.contains(.inbox))
        #expect(ThoughtScope.all.contains(.archived(at: epoch)))
    }
}

@Suite("Thought lifecycle actions")
struct ThoughtLifecycleTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("archiving does not count as attention paid to the thought")
    func archivingIsNotAnAction() {
        var subject = Thought(body: "expired", capturedAt: epoch)
        subject.archive(at: epoch.addingTimeInterval(30 * .day))

        #expect(subject.lastActedAt == epoch)
        #expect(subject.state == .archived(at: epoch.addingTimeInterval(30 * .day)))
    }

    @Test("restoring returns a thought to the inbox at full freshness")
    func restoringRevives() {
        var subject = Thought(body: "rescued", capturedAt: epoch, state: .archived(at: epoch))
        let later = epoch.addingTimeInterval(90 * .day)
        subject.restore(at: later)

        #expect(subject.state == .inbox)
        #expect(DecayEngine().freshness(of: subject, at: later) == .full)
    }
}
