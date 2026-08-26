@testable import DesignSystem
import SwiftUI
import Testing

/// The contrast audit, run as a test rather than done by eye.
///
/// Every pairing the app actually draws is checked in all four appearances: light and dark, each
/// at standard and increased contrast. WCAG AA asks for 4.5:1 on body text and 3:1 on large text
/// and on meaningful non-text marks.
@Suite("Palette contrast")
struct PaletteContrastTests {
    /// One appearance the palette has to survive.
    private struct Appearance {
        let name: String
        let scheme: ColorScheme
        let increased: Bool
    }

    /// The four appearances every pairing has to survive.
    private static let appearances = [
        Appearance(name: "light", scheme: .light, increased: false),
        Appearance(name: "light increased", scheme: .light, increased: true),
        Appearance(name: "dark", scheme: .dark, increased: false),
        Appearance(name: "dark increased", scheme: .dark, increased: true)
    ]

    /// Checks one foreground against one background in every appearance.
    private func check(
        _ foreground: ThemedColor,
        on background: ThemedColor,
        atLeast minimum: Double,
        _ what: String
    ) {
        for appearance in Self.appearances {
            let ink = foreground.value(scheme: appearance.scheme, increasedContrast: appearance.increased)
            let ground = background.value(scheme: appearance.scheme, increasedContrast: appearance.increased)
            let ratio = ink.contrastRatio(against: ground)
            #expect(
                ratio >= minimum,
                "\(what) in \(appearance.name): \(String(format: "%.2f", ratio)):1, needs \(minimum):1"
            )
        }
    }

    @Test("body text clears AA on both surfaces")
    func bodyTextIsReadable() {
        check(Palette.inkValues, on: Palette.surfaceValues, atLeast: 4.5, "ink on surface")
        check(Palette.inkValues, on: Palette.raisedValues, atLeast: 4.5, "ink on raised")
    }

    @Test("supporting text clears AA, because a timestamp nobody can read is decoration")
    func supportingTextIsReadable() {
        check(Palette.inkMutedValues, on: Palette.surfaceValues, atLeast: 4.5, "muted on surface")
        check(Palette.inkMutedValues, on: Palette.raisedValues, atLeast: 4.5, "muted on raised")
    }

    @Test("the accent used as text clears AA on both surfaces")
    func accentTextIsReadable() {
        check(Palette.accentTextValues, on: Palette.surfaceValues, atLeast: 4.5, "accent text on surface")
        check(Palette.accentTextValues, on: Palette.raisedValues, atLeast: 4.5, "accent text on raised")
    }

    @Test("the expiry warning colour clears AA, since it is the one thing that must be noticed")
    func fadingIsReadable() {
        check(Palette.fadingValues, on: Palette.surfaceValues, atLeast: 4.5, "fading on surface")
        check(Palette.fadingValues, on: Palette.raisedValues, atLeast: 4.5, "fading on raised")
    }

    @Test("white on the prominent fill clears AA")
    func prominentButtonsAreReadable() {
        let white = ThemedColor(light: RGB(1, 1, 1), dark: RGB(1, 1, 1))
        check(white, on: Palette.accentValues, atLeast: 4.5, "white on accent")
    }

    @Test("a raised row is distinguishable from the page behind it")
    func surfacesAreDistinguishable() {
        for appearance in Self.appearances where appearance.scheme == .dark {
            let raised = Palette.raisedValues.value(
                scheme: appearance.scheme, increasedContrast: appearance.increased
            )
            let surface = Palette.surfaceValues.value(
                scheme: appearance.scheme, increasedContrast: appearance.increased
            )
            #expect(raised.relativeLuminance > surface.relativeLuminance)
        }
    }
}

/// The fade is the app's core signal, and it is the one thing most likely to make text
/// unreadable. These pin the floor rather than trusting it.
@Suite("The fade stays readable")
struct FreshnessContrastTests {
    @Test("a thought at the very end of its life is still readable, on either background")
    func fullyFadedTextClearsAA() {
        let backgrounds = [
            ("surface", Palette.surfaceValues),
            ("raised", Palette.raisedValues)
        ]

        for scheme in [ColorScheme.light, .dark] {
            for (name, background) in backgrounds {
                let ink = Palette.inkValues.value(scheme: scheme, increasedContrast: false)
                let ground = background.value(scheme: scheme, increasedContrast: false)
                let seen = ink.blended(over: ground, opacity: FreshnessStyle.opacity(for: 0))
                let ratio = seen.contrastRatio(against: ground)
                #expect(
                    ratio >= 4.5,
                    "faded ink on \(name) in \(scheme): \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    @Test("increased contrast stops the fade entirely rather than softening it")
    func increasedContrastDoesNotFade() {
        for freshness in stride(from: 0.0, through: 1.0, by: 0.1) {
            #expect(FreshnessStyle.opacity(for: freshness, increasedContrast: true) == 1)
        }
    }

    @Test("the fade still says something: a fresh thought is drawn stronger than a stale one")
    func fadeStillCarriesTheSignal() {
        #expect(FreshnessStyle.opacity(for: 1) > FreshnessStyle.opacity(for: 0))
        #expect(FreshnessStyle.opacity(for: 1) == 1)
        #expect(FreshnessStyle.opacity(for: 0) == FreshnessStyle.minimumOpacity)
    }

    @Test("opacity is clamped, so a bad freshness value cannot make a thought invisible")
    func opacityIsClamped() {
        #expect(FreshnessStyle.opacity(for: -5) == FreshnessStyle.minimumOpacity)
        #expect(FreshnessStyle.opacity(for: 99) == 1)
    }
}
