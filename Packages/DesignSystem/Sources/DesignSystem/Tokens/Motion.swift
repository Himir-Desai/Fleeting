import SwiftUI

/// Animation timings. Named by intent so that Reduce Motion can be honoured centrally.
///
/// Views apply these through `View.motion(_:value:)` or a Reduce Motion-aware state transition
/// (ADR-0020).
public enum Motion {
    /// The freshness fade, and any change that should feel like it was already happening.
    public static let decay = Animation.easeInOut(duration: 0.45)

    /// Expanding or contracting the contextual native tab set without overshoot.
    public static let navigation = Animation.spring(response: 0.3, dampingFraction: 1)

    /// Committing a capture: fast enough not to delay the next thought.
    public static let commit = Animation.easeOut(duration: 0.18)

    /// Dismissing a review card.
    public static let card = Animation.spring(response: 0.34, dampingFraction: 1)

    /// A sprout drawing itself: slow enough to read as growth rather than a flicker, and slower
    /// at the end than the start, the way a thing that grows actually behaves (ADR-0042).
    public static let growth = Animation.easeOut(duration: 0.85)
}
