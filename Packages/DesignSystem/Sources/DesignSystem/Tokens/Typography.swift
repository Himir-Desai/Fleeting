import SwiftUI

/// The app's type scale. Every style is built from a Dynamic Type text style so that
/// accessibility sizing works without per-site handling.
public enum Typography {
    /// The capture field — the largest comfortable size for one-handed typing.
    public static let capture = Font.system(.title3, design: .default, weight: .regular)

    /// A generated thought title in a list.
    public static let title = Font.system(.headline, design: .default, weight: .semibold)

    /// Raw captured text.
    public static let body = Font.system(.body, design: .default)

    /// Timestamps, counts, and freshness labels.
    public static let caption = Font.system(.caption, design: .default)
}
