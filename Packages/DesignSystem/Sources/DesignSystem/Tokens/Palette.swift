import SwiftUI

/// The app's colour vocabulary. Features reference these rather than literal colours,
/// so the freshness fade can be retuned in one place.
public enum Palette {
    /// The page behind everything.
    public static let surface = Color(red: 0.04, green: 0.04, blue: 0.05)

    /// Raised surfaces such as thought rows and review cards.
    public static let raised = Color(red: 0.10, green: 0.10, blue: 0.12)

    /// Text at full freshness.
    public static let ink = Color(red: 0.96, green: 0.96, blue: 0.94)

    /// Supporting text and timestamps.
    public static let inkMuted = Color(red: 0.58, green: 0.58, blue: 0.60)

    /// The single accent, used for the act affordance and nothing decorative.
    public static let accent = Color(red: 0.42, green: 0.36, blue: 0.90)

    /// Applied to a thought that is close to expiring.
    public static let fading = Color(red: 0.78, green: 0.55, blue: 0.28)
}
