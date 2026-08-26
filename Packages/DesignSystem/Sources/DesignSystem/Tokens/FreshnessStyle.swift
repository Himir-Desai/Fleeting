import SwiftUI

/// How freshness is expressed visually.
///
/// Takes a plain number rather than a domain type (ADR-0012), so the design layer stays free of
/// domain knowledge.
public enum FreshnessStyle {
    /// The lowest opacity a fading thought is ever drawn at.
    ///
    /// Set by the contrast audit rather than by eye: below this, ink blended over the page falls
    /// under the WCAG AA ratio for body text and an old thought becomes genuinely hard to read.
    /// The number is the one the *light* appearance needs, which is stricter than dark, so there
    /// is a single floor rather than one per appearance (ADR-0020).
    public static let minimumOpacity = 0.60

    /// Opacity for a thought's content at the given freshness.
    ///
    /// Never reaches zero: a fading thought must stay readable, because the fade is a signal and
    /// not a punishment.
    /// - Parameters:
    ///   - freshness: A value within 0...1.
    ///   - increasedContrast: When `true`, the text is not faded at all. The meter and the
    ///     "archives in" label still carry the signal, so nothing is lost by keeping the words
    ///     at full strength.
    /// - Returns: An opacity within `minimumOpacity`...1.
    public static func opacity(for freshness: Double, increasedContrast: Bool = false) -> Double {
        guard !increasedContrast else { return 1 }
        let clamped = min(max(freshness, 0), 1)
        return minimumOpacity + (1 - minimumOpacity) * clamped
    }

    /// The colour of the freshness meter at the given freshness.
    /// - Parameter freshness: A value within 0...1.
    /// - Returns: The accent colour while healthy, warming towards the fading colour as it runs out.
    public static func tint(for freshness: Double) -> Color {
        freshness < 0.35 ? Palette.fading : Palette.accentText
    }
}
