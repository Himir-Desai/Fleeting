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

    /// Below this, a thought is drawn in the warning colour rather than the accent.
    public static let expiringBelow = 0.20

    /// Below this, the tint has begun to warm but has not yet become a warning.
    public static let fadingBelow = 0.45

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
        let clamped = clamp(freshness)
        return minimumOpacity + (1 - minimumOpacity) * clamped
    }

    /// The font weight that expresses freshness: heavier while fresh, lighter as it fades.
    ///
    /// The primary freshness signal where a meter is not drawn (ADR-0025). Kept to three steps and
    /// never lighter than regular, so a faded thought stays legible under the opacity floor.
    /// - Parameter freshness: A value within 0...1.
    /// - Returns: A font weight from `.regular` (faded) to `.semibold` (fresh).
    public static func weight(for freshness: Double) -> Font.Weight {
        let clamped = clamp(freshness)
        if clamped >= 0.66 {
            return .semibold
        }
        if clamped >= 0.33 {
            return .medium
        }
        return .regular
    }

    /// The middle stop of the meter: a thought that has begun to run down but is not yet a
    /// warning.
    ///
    /// Derived from two audited colours rather than picked, and audited itself, so the whole
    /// slope is covered by the contrast test instead of only its ends.
    public static let warmingValues = Palette.fadingValues.mixed(
        with: Palette.accentTextValues, by: 0.45
    )

    /// The colour of the freshness meter and rail at the given freshness.
    ///
    /// Three stops rather than two, so the meter reads as a slope the thought is sliding down
    /// instead of a light that switches from fine to nearly gone.
    /// - Parameter freshness: A value within 0...1.
    /// - Returns: The accent while healthy, warming towards the fading colour as it runs out.
    public static func tint(for freshness: Double) -> Color {
        let clamped = clamp(freshness)
        if clamped < expiringBelow {
            return Palette.fading
        }
        if clamped < fadingBelow {
            return warmingValues.color
        }
        return Palette.accentText
    }

    /// The unfilled part of the freshness meter: the life a thought has already spent.
    public static var track: Color {
        Palette.separator
    }

    /// How prominent the rail down a row's leading edge should be.
    ///
    /// The rail is a second reading of the same number in a different axis, so it stays quiet
    /// while a thought is healthy and only asserts itself near the end.
    /// - Parameter freshness: A value within 0...1.
    /// - Returns: An opacity within 0...1.
    public static func railOpacity(for freshness: Double) -> Double {
        clamp(freshness) < expiringBelow ? 1 : 0.55
    }

    /// Confines a freshness value to 0...1, so a bad number cannot produce a bad drawing.
    private static func clamp(_ freshness: Double) -> Double {
        min(max(freshness, 0), 1)
    }
}
