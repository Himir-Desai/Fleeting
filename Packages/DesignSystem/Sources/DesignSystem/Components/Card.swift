import SwiftUI

/// Content on a raised, rounded, inset surface.
///
/// For cards that stand on their own. A card inside a `List` uses ``CardSurface`` as its row
/// background instead, so the list keeps its swipe actions.
public struct Card<Content: View>: View {
    private let elevation: Elevation
    private let content: Content

    /// Creates a card.
    /// - Parameters:
    ///   - elevation: How far off the page it sits. Defaults to ``Elevation/card``.
    ///   - content: What the card holds.
    public init(elevation: Elevation = .card, @ViewBuilder content: () -> Content) {
        self.elevation = elevation
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.inset)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.raised)
                    .elevated(elevation, cornerRadius: Radius.card)
            }
    }
}
