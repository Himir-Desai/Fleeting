import Foundation

/// Supplies the current wall-clock time.
///
/// Types whose behaviour depends on the passage of time take a `WallClock` instead of
/// reading the system clock, so tests can drive time forward without waiting.
public protocol WallClock: Sendable {
    /// The current instant.
    var now: Date { get }
}

/// A `WallClock` backed by the device's system time.
///
/// This is the only type in the app permitted to construct a `Date` from the system clock.
public struct SystemClock: WallClock {
    public var now: Date {
        Date()
    }

    /// Creates a clock reading the system time.
    public init() {}
}
