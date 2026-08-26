import SwiftUI

/// One palette entry, in every appearance the app has to look right in.
///
/// Increased-contrast variants are separate values rather than a computed adjustment, so the
/// contrast audit tests the colours that actually ship.
public struct ThemedColor: Sendable {
    /// Light appearance, standard contrast.
    public let light: RGB
    /// Dark appearance, standard contrast.
    public let dark: RGB
    /// Light appearance when the user has asked for increased contrast.
    public let lightIncreased: RGB
    /// Dark appearance when the user has asked for increased contrast.
    public let darkIncreased: RGB

    /// Creates a palette entry.
    /// - Parameters:
    ///   - light: Light appearance, standard contrast.
    ///   - dark: Dark appearance, standard contrast.
    ///   - lightIncreased: Light appearance under increased contrast. Defaults to `light`.
    ///   - darkIncreased: Dark appearance under increased contrast. Defaults to `dark`.
    public init(light: RGB, dark: RGB, lightIncreased: RGB? = nil, darkIncreased: RGB? = nil) {
        self.light = light
        self.dark = dark
        self.lightIncreased = lightIncreased ?? light
        self.darkIncreased = darkIncreased ?? dark
    }

    /// The value used in a given appearance.
    /// - Parameters:
    ///   - scheme: Light or dark.
    ///   - increasedContrast: Whether the user has asked for increased contrast.
    /// - Returns: The components that will be drawn.
    public func value(scheme: ColorScheme, increasedContrast: Bool) -> RGB {
        switch (scheme, increasedContrast) {
        case (.light, false): light
        case (.light, true): lightIncreased
        case (_, false): dark
        case (_, true): darkIncreased
        }
    }

    #if canImport(UIKit)
        /// A colour that follows the appearance and contrast setting in force.
        public var color: Color {
            Color(UIColor { traits in
                let scheme: ColorScheme = traits.userInterfaceStyle == .light ? .light : .dark
                let increased = traits.accessibilityContrast == .high
                let rgb = value(scheme: scheme, increasedContrast: increased)
                return UIColor(
                    red: rgb.red,
                    green: rgb.green,
                    blue: rgb.blue,
                    alpha: 1
                )
            })
        }
    #else
        /// A fixed colour. The package builds on macOS only so its tests can run without a
        /// simulator; the app itself is iOS-only, where the adaptive path above is used.
        public var color: Color {
            dark.color
        }
    #endif
}
