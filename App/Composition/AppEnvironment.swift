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
