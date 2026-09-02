import SwiftUI

/// The app's type scale. Every style is built from a Dynamic Type text style so that
/// accessibility sizing works without per-site handling.
///
/// The scale has one deliberate break in it, and it carries a rule: **the serif is for the user's
/// own words, and the sans is for everything the app says** (ADR-0037). A captured fragment is the
/// content; the interface around it is furniture. Setting the two in different families is what
/// makes that legible without a single label.
public enum Typography {
    /// The app speaking: an empty state's headline, the end of a review session.
    public static let display = Font.system(.title, design: .serif, weight: .regular)

    /// The capture field — the largest comfortable size for one-handed typing.
    ///
    /// Serif, because what is being typed into it is the user's own words (ADR-0037).
    public static let capture = Font.system(.title3, design: .serif, weight: .regular)

    /// A thought's own words, quoted back at the size of a heading: the review's card, the raw
    /// text a sharpened write-up was built from.
    ///
    /// The user's voice, so it is set in the serif (ADR-0037).
    public static let quoted = Font.system(.title3, design: .serif, weight: .regular)

    /// A generated title standing over the user's own prose.
    ///
    /// Serif, because a write-up is the user's idea developed from their answers rather than
    /// something the app is telling them (ADR-0037).
    public static let writtenTitle = Font.system(.headline, design: .serif, weight: .semibold)

    /// A screen's own headings, and a generated thought title.
    public static let title = Font.system(.headline, design: .default, weight: .semibold)

    /// A status line's first sentence: the answer, above the explanation.
    public static let subtitle = Font.system(.subheadline, design: .default, weight: .medium)

    /// Raw captured text.
    public static let body = Font.system(.body, design: .default)

    /// A thought's own words at body size: one row in a list of them.
    ///
    /// The serif at reading size, so a list of thoughts reads as a page of the user's writing
    /// rather than a table of records (ADR-0037).
    public static let serifBody = Font.system(.body, design: .serif)

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
