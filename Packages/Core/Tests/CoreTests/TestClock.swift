import Foundation
@testable import Core

/// A `WallClock` whose time is set explicitly, so time-dependent behaviour can be tested
/// without waiting for it.
final class TestClock: WallClock, @unchecked Sendable {
    // Justification for @unchecked: mutated only from a single test at a time; the
    // alternative is an actor, which would force every call site to be async.
    private var current: Date

    var now: Date { current }

    /// Creates a clock stopped at the given instant.
    /// - Parameter start: The instant the clock reads until advanced.
    init(start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        current = start
    }

    /// Moves the clock forward.
    /// - Parameter days: How many days to advance.
    func advance(days: Double) {
        current = current.addingTimeInterval(days * 86_400)
    }
}
