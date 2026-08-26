import SwiftUI

/// The app's type scale. Every style is built from a Dynamic Type text style so that
/// accessibility sizing works without per-site handling.
///
/// The scale has one deliberate break in it: ``display`` is a serif, and nothing else is. It
/// appears only where the app speaks rather than labels — an empty state, the end of a review —
/// so the voice is distinctive without the interface becoming a magazine (ADR-0022).
public enum Typography {
    /// The app speaking: an empty state's headline, the end of a review session.
    public static let display = Font.system(.title, design: .serif, weight: .regular)

    /// The capture field — the largest comfortable size for one-handed typing.
    public static let capture = Font.system(.title3, design: .default, weight: .regular)

    /// A screen's own headings, and a generated thought title.
    public static let title = Font.system(.headline, design: .default, weight: .semibold)

    /// A status line's first sentence: the answer, above the explanation.
    public static let subtitle = Font.system(.subheadline, design: .default, weight: .medium)

    /// Raw captured text.
    public static let body = Font.system(.body, design: .default)

    /// A thought's own words, where they are the subject of the screen rather than one item in a
    /// list. Heavier than ``body`` so metadata beside it recedes.
    public static let emphasis = Font.system(.body, design: .default, weight: .medium)

    /// Timestamps, counts, and freshness labels.
    public static let caption = Font.system(.caption, design: .default)

    /// A section's name, set small and wide. Always paired with ``Palette/inkMuted``.
    public static let label = Font.system(.caption2, design: .default, weight: .semibold)

    /// A symbol used as illustration rather than as a control — the mark above an empty state.
    public static let symbol = Font.largeTitle

    /// A number that is the subject of the surface it is on, such as a widget's live count.
    public static let numeral = Font.system(.largeTitle, design: .default, weight: .semibold)

    /// The tracking applied to ``label``, which is set in small caps and needs the air.
    public static let labelTracking: CGFloat = 0.8
}
