import SwiftUI

/// Draws a surface at a given elevation, in whichever way the appearance can actually show it.
private struct Elevated: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    let level: Elevation
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(
                color: usesShadow ? Palette.ink.opacity(level.shadowOpacity) : .clear,
                radius: usesShadow ? level.blur : 0,
                y: usesShadow ? level.offset : 0
            )
            .overlay {
                if !usesShadow, level != .flat {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Palette.separator, lineWidth: 1)
                }
            }
    }

    /// Whether a shadow would be visible at all.
    ///
    /// A drop shadow on a near-black page is a shadow nobody can see, and under increased
    /// contrast an edge is what was asked for. Both cases get the hairline instead.
    private var usesShadow: Bool {
        scheme == .light && contrast != .increased
    }
}

public extension View {
    /// Lifts this view off the page, with a shadow or a hairline depending on the appearance.
    ///
    /// The single place elevation is drawn, so no feature has to know that dark mode needs an
    /// outline where light mode needs a shadow.
    /// - Parameters:
    ///   - level: How far off the page the surface sits.
    ///   - cornerRadius: The radius of the surface being lifted, so an outline follows its edge.
    /// - Returns: The view, elevated.
    func elevated(_ level: Elevation, cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(Elevated(level: level, cornerRadius: cornerRadius))
    }
}
