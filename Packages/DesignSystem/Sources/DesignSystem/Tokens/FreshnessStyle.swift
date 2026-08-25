import SwiftUI

/// How freshness is expressed visually.
///
/// Takes a plain number rather than a domain type (ADR-0012), so the design layer stays free of
/// domain knowledge.
public enum FreshnessStyle {
    /// Opacity for a thought's content at the given freshness.
    ///
    /// Never reaches zero: a fading thought must stay readable, because the fade is a signal and
    /// not a punishment.
    /// - Parameter freshness: A value within 0...1.
    /// - Returns: An opacity within 0.38...1.
    public static func opacity(for freshness: Double) -> Double {
        0.38 + 0.62 * min(max(freshness, 0), 1)
    }

    /// The colour of the freshness meter at the given freshness.
    /// - Parameter freshness: A value within 0...1.
    /// - Returns: The accent colour while healthy, warming towards the fading colour as it runs out.
    public static func tint(for freshness: Double) -> Color {
        freshness < 0.35 ? Palette.fading : Palette.accent
    }
}
