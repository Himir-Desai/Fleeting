import Core
import Foundation
import Persistence

/// The composition root: the single place where protocols are bound to concrete types.
///
/// Nothing below the app layer names an implementation, so swapping storage or intelligence
/// is a change to this file alone.
@MainActor
final class AppEnvironment {
    /// The time source injected into everything that decays.
    let clock: any WallClock

    /// Storage for captured thoughts.
    let thoughts: any ThoughtRepository

    /// Creates the environment.
    /// - Parameters:
    ///   - clock: Time source. Defaults to the system clock.
    ///   - thoughts: Thought storage. Defaults to an in-memory store until Phase 1 adds SwiftData.
    init(
        clock: any WallClock = SystemClock(),
        thoughts: any ThoughtRepository = InMemoryThoughtRepository()
    ) {
        self.clock = clock
        self.thoughts = thoughts
    }
}
