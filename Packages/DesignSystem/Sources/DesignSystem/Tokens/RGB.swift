import SwiftUI

/// A colour held as sRGB components so its contrast can be computed and tested.
///
/// `Color` cannot be read back portably, so every palette value is defined here first and turned
/// into a `Color` second. That is what lets the contrast audit run as a unit test.
public struct RGB: Equatable, Sendable {
    /// Red, within 0...1.
    public let red: Double
    /// Green, within 0...1.
    public let green: Double
    /// Blue, within 0...1.
    public let blue: Double

    /// Creates a colour from sRGB components.
    /// - Parameters:
    ///   - red: Red, within 0...1.
    ///   - green: Green, within 0...1.
    ///   - blue: Blue, within 0...1.
    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The SwiftUI colour these components describe.
    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// Relative luminance as defined by WCAG 2.1.
    public var relativeLuminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    /// The WCAG contrast ratio between this colour and another, from 1 to 21.
    /// - Parameter other: The colour to compare against, usually a background.
    /// - Returns: The ratio, where 4.5 is the minimum for body text.
    public func contrastRatio(against other: RGB) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// This colour composited over a background at a given opacity.
    ///
    /// Fading text is drawn with opacity, so its real contrast is against the blend, not the
    /// original colour.
    /// - Parameters:
    ///   - background: What the colour is drawn on top of.
    ///   - opacity: The opacity it is drawn at, within 0...1.
    /// - Returns: The colour actually seen.
    public func blended(over background: RGB, opacity: Double) -> RGB {
        let alpha = min(max(opacity, 0), 1)
        return RGB(
            red * alpha + background.red * (1 - alpha),
            green * alpha + background.green * (1 - alpha),
            blue * alpha + background.blue * (1 - alpha)
        )
    }

    /// Converts one sRGB component to its linear-light value.
    private static func linear(_ component: Double) -> Double {
        component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }
}
