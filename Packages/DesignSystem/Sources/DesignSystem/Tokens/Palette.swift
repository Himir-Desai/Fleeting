import SwiftUI

/// The app's colour vocabulary. Features reference these rather than literal colours,
/// so the freshness fade can be retuned in one place.
///
/// Every value is defined as a ``ThemedColor`` and audited by `PaletteContrastTests`, which fails
/// the build if any pairing the app actually draws falls below the WCAG AA ratio for its size.
public enum Palette {
    /// The page behind everything.
    public static let surfaceValues = ThemedColor(
        light: RGB(0.965, 0.965, 0.949),
        dark: RGB(0.04, 0.04, 0.05),
        lightIncreased: RGB(1, 1, 1),
        darkIncreased: RGB(0, 0, 0)
    )

    /// Raised surfaces such as thought rows and review cards.
    public static let raisedValues = ThemedColor(
        light: RGB(1, 1, 1),
        dark: RGB(0.10, 0.10, 0.12),
        lightIncreased: RGB(1, 1, 1),
        darkIncreased: RGB(0.13, 0.13, 0.16)
    )

    /// Text at full freshness.
    public static let inkValues = ThemedColor(
        light: RGB(0.082, 0.082, 0.102),
        dark: RGB(0.96, 0.96, 0.94),
        lightIncreased: RGB(0, 0, 0),
        darkIncreased: RGB(1, 1, 1)
    )

    /// Supporting text and timestamps.
    public static let inkMutedValues = ThemedColor(
        light: RGB(0.361, 0.361, 0.380),
        dark: RGB(0.58, 0.58, 0.60),
        lightIncreased: RGB(0.24, 0.24, 0.26),
        darkIncreased: RGB(0.74, 0.74, 0.76)
    )

    /// The fill behind a prominent control. Chosen so white text on it clears AA.
    public static let accentValues = ThemedColor(
        light: RGB(0.31, 0.25, 0.82),
        dark: RGB(0.36, 0.29, 0.84),
        lightIncreased: RGB(0.24, 0.18, 0.72),
        darkIncreased: RGB(0.30, 0.23, 0.78)
    )

    /// The accent used as text or a tint on a surface. Lighter in the dark appearance, because a
    /// fill colour and a text colour cannot be the same value and both clear AA.
    public static let accentTextValues = ThemedColor(
        light: RGB(0.29, 0.227, 0.784),
        dark: RGB(0.56, 0.505, 0.949),
        lightIncreased: RGB(0.20, 0.15, 0.66),
        darkIncreased: RGB(0.68, 0.64, 0.98)
    )

    /// Applied to a thought that is close to expiring.
    public static let fadingValues = ThemedColor(
        light: RGB(0.541, 0.353, 0.071),
        dark: RGB(0.878, 0.659, 0.361),
        lightIncreased: RGB(0.42, 0.26, 0.03),
        darkIncreased: RGB(0.94, 0.76, 0.50)
    )

    /// The page behind everything.
    public static var surface: Color {
        surfaceValues.color
    }

    /// Raised surfaces such as thought rows and review cards.
    public static var raised: Color {
        raisedValues.color
    }

    /// Text at full freshness.
    public static var ink: Color {
        inkValues.color
    }

    /// Supporting text and timestamps.
    public static var inkMuted: Color {
        inkMutedValues.color
    }

    /// The fill behind a prominent control.
    public static var accent: Color {
        accentValues.color
    }

    /// The accent used as text or a tint on a surface.
    public static var accentText: Color {
        accentTextValues.color
    }

    /// Applied to a thought that is close to expiring.
    public static var fading: Color {
        fadingValues.color
    }
}
