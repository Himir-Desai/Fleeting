import SwiftUI

/// Animation timings. Named by intent so that Reduce Motion can be honoured centrally.
///
/// Nothing applies these directly. Use `View.motion(_:value:)`, which drops the animation when
/// the system asks for reduced motion (ADR-0020).
public enum Motion {
    /// The freshness fade, and any change that should feel like it was already happening.
    public static let decay = Animation.easeInOut(duration: 0.45)

    /// Committing a capture: fast enough not to delay the next thought.
    public static let commit = Animation.easeOut(duration: 0.18)

    /// Dismissing a review card.
    public static let card = Animation.spring(response: 0.34, dampingFraction: 0.82)
}
