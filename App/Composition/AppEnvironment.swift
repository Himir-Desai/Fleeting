import Core
import Foundation
import Persistence

/// The composition root: the single place where protocols are bound to concrete types.
///
/// Nothing below the app layer names an implementation, so swapping storage or intelligence
/// is a change to this file alone.
@MainActor
final class AppEnvironment {
    /// Launch argument that makes the app start from an empty store, used by the UI tests.
    static let resetStoreArgument = "--reset-store"

    /// The time source injected into everything that decays.
    let clock: any WallClock

    /// Storage for captured thoughts.
    let thoughts: any ThoughtRepository

    /// Computes freshness and decides what has expired.
    let engine: DecayEngine

    /// Moves expired thoughts into the archive.
    let sweeper: any ArchiveSweeping

    /// Whether the on-disk store failed to open and captures are being held in memory only.
    ///
    /// Surfaced quietly inside the app rather than at launch: a storage problem must never
    /// stand between a cold launch and a focused field (ADR-0008).
    let storageIsDegraded: Bool

    /// Creates the environment.
    /// - Parameters:
    ///   - clock: Time source. Defaults to the system clock.
    ///   - thoughts: Thought storage. Defaults to the on-disk SwiftData store, falling back to
    ///     an in-memory store if it cannot be opened.
    init(clock: any WallClock = SystemClock(), thoughts: (any ThoughtRepository)? = nil) {
        self.clock = clock
        if let thoughts {
            self.thoughts = thoughts
            storageIsDegraded = false
        } else {
            let store = Self.openStore()
            self.thoughts = store.repository
            storageIsDegraded = store.degraded
        }
        engine = DecayEngine()
        sweeper = ArchiveSweeper(repository: self.thoughts, engine: engine, clock: clock)
    }

    /// Prepares the store after launch: seeds demo data when asked, then archives anything that
    /// expired while the app was closed.
    ///
    /// Runs after the capture field is on screen, never before it.
    func prepare() async {
        #if DEBUG
            await seedDemoDataIfRequested()
        #endif
        await sweep()
    }

    #if DEBUG
        /// Launch argument that fills an empty store with thoughts at a spread of ages, for
        /// screenshots and for exercising decay by hand. Debug builds only.
        static let seedDemoArgument = "--seed-demo"

        /// Inserts demo thoughts if asked and the store is empty.
        private func seedDemoDataIfRequested() async {
            guard ProcessInfo.processInfo.arguments.contains(Self.seedDemoArgument),
                  let existing = try? await thoughts.thoughts(in: .all), existing.isEmpty
            else { return }

            let now = clock.now
            let demo: [(String, Double)] = [
                ("ship the decay engine before it decays", 0.2),
                ("call the dentist back", 12),
                ("newsletter about tools that do one thing", 22),
                ("learn to sail? or is that a boat-shaped midlife crisis", 29)
            ]

            for (body, ageInDays) in demo {
                let captured = now.addingTimeInterval(-ageInDays * .day)
                try? await thoughts.add(Thought(body: body, capturedAt: captured))
            }
        }
    #endif

    /// Archives anything that expired while the app was closed.
    ///
    /// Failures are ignored on purpose: a sweep that cannot run must never surface at launch or
    /// interfere with capture (ADR-0008). The next sweep will pick the work up.
    func sweep() async {
        _ = try? await sweeper.sweep()
    }

    /// Opens the on-disk store, degrading to memory rather than failing to launch.
    /// - Returns: The repository to use, and whether it is the degraded in-memory one.
    private static func openStore() -> (repository: any ThoughtRepository, degraded: Bool) {
        let reset = ProcessInfo.processInfo.arguments.contains(resetStoreArgument)
        do {
            let container = try ModelContainerFactory.store(resettingFirst: reset)
            return (SwiftDataThoughtRepository(modelContainer: container), false)
        } catch {
            return (InMemoryThoughtRepository(), true)
        }
    }
}
