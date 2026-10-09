import SwiftUI

/// The app's colour vocabulary. Features reference these rather than literal colours,
/// so the freshness fade can be retuned in one place.
///
/// The light appearance is paper and the dark appearance is ink: both are warm rather than
/// neutral, so a screen of text reads as something written on rather than something rendered
/// (ADR-0022).
///
/// Every value is defined as a ``ThemedColor`` and audited by `PaletteContrastTests`, which fails
/// the build if any pairing the app actually draws falls below the WCAG AA ratio for its size.
public enum Palette {
    /// The page behind everything.
    public static let surfaceValues = ThemedColor(
        light: RGB(0.976, 0.969, 0.949),
        dark: RGB(22 / 255, 19 / 255, 17 / 255),
        lightIncreased: RGB(1, 1, 1),
        darkIncreased: RGB(15 / 255, 13 / 255, 11 / 255)
    )

    /// A recess in the page: the capture field's well, and search fields.
    ///
    /// Reads as below the page rather than on it, which is what separates a field the user types
    /// into from a card the app has put there.
    public static let surfaceSunkenValues = ThemedColor(
        light: RGB(0.937, 0.929, 0.906),
        dark: RGB(14 / 255, 12 / 255, 10 / 255),
        lightIncreased: RGB(0.898, 0.890, 0.867),
        darkIncreased: RGB(9 / 255, 8 / 255, 7 / 255)
    )

    /// Raised surfaces such as thought rows and review cards.
    public static let raisedValues = ThemedColor(
        light: RGB(1, 1, 1),
        dark: RGB(35 / 255, 30 / 255, 26 / 255),
        lightIncreased: RGB(1, 1, 1),
        darkIncreased: RGB(45 / 255, 38 / 255, 32 / 255)
    )

    /// Text at full freshness.
    public static let inkValues = ThemedColor(
        light: RGB(0.086, 0.078, 0.066),
        dark: RGB(245 / 255, 237 / 255, 223 / 255),
        lightIncreased: RGB(0, 0, 0),
        darkIncreased: RGB(1, 245 / 255, 232 / 255)
    )

    /// Supporting text and timestamps.
    public static let inkMutedValues = ThemedColor(
        light: RGB(0.361, 0.345, 0.318),
        dark: RGB(183 / 255, 170 / 255, 157 / 255),
        lightIncreased: RGB(0.235, 0.220, 0.196),
        darkIncreased: RGB(0.749, 0.741, 0.722)
    )

    /// Hairlines between rows and around cards. Decoration, not information, so it carries no
    /// contrast minimum of its own.
    public static let separatorValues = ThemedColor(
        light: RGB(0.878, 0.867, 0.839),
        dark: RGB(81 / 255, 69 / 255, 60 / 255),
        lightIncreased: RGB(0.639, 0.627, 0.600),
        darkIncreased: RGB(129 / 255, 112 / 255, 96 / 255)
    )

    /// Purple in light appearance, sage in dark; white text clears AA on both.
    public static let accentValues = ThemedColor(
        light: RGB(0.31, 0.25, 0.82),
        dark: RGB(0.29, 0.38, 0.31),
        lightIncreased: RGB(0.24, 0.18, 0.72),
        darkIncreased: RGB(0.22, 0.32, 0.24)
    )

    /// Text and meaningful marks on a prominent fill in every appearance.
    public static let onAccentValues = ThemedColor(light: RGB(1, 1, 1), dark: RGB(1, 1, 1))

    /// The accent used as text or a tint on a surface. Lighter in the dark appearance, because a
    /// fill colour and a text colour cannot be the same value and both clear AA.
    public static let accentTextValues = ThemedColor(
        light: RGB(0.29, 0.227, 0.784),
        dark: RGB(0.68, 0.79, 0.71),
        lightIncreased: RGB(0.20, 0.15, 0.66),
        darkIncreased: RGB(0.78, 0.90, 0.81)
    )

    /// A quiet tinted fill: the chip behind a glyph, the ground under a highlighted row.
    ///
    /// Audited as a background in its own right, because ``accentText`` is drawn on it.
    public static let accentSoftValues = ThemedColor(
        light: RGB(0.925, 0.918, 0.984),
        dark: RGB(0.14, 0.19, 0.155),
        lightIncreased: RGB(0.902, 0.894, 0.980),
        darkIncreased: RGB(0.12, 0.20, 0.145)
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

    /// A recess in the page: the capture field's well, and search fields.
    public static var surfaceSunken: Color {
        surfaceSunkenValues.color
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

    /// Hairlines between rows and around cards.
    public static var separator: Color {
        separatorValues.color
    }

    /// The fill behind a prominent control.
    public static var accent: Color {
        accentValues.color
    }

    /// The accent used as text or a tint on a surface.
    public static var accentText: Color {
        accentTextValues.color
    }

    /// Text and meaningful marks on a prominent control.
    public static var onAccent: Color {
        onAccentValues.color
    }

    /// A quiet tinted fill: the chip behind a glyph, the ground under a highlighted row.
    public static var accentSoft: Color {
        accentSoftValues.color
    }

    /// Applied to a thought that is close to expiring.
    public static var fading: Color {
        fadingValues.color
    }
}
