import SwiftUI

/// The ground a card sits on: a raised, rounded surface with an optional tinted rail down its
/// leading edge.
///
/// A view rather than a modifier so it can also be handed to `List.listRowBackground`, which is
/// what turns a plain list into a stack of cards without giving up the list's swipe actions.
public struct CardSurface: View {
    private let rail: Color?
    private let railOpacity: Double
    private let elevation: Elevation

    /// The freshness this surface belongs to, or `nil` for a card that is not a thought.
    ///
    /// Held rather than resolved up front because the fill depends on the contrast setting, which
    /// is only known once the view is in an environment.
    private let freshness: Double?

    @Environment(\.colorSchemeContrast) private var contrast

    /// Creates the surface.
    /// - Parameters:
    ///   - rail: A colour for the 3pt marker down the leading edge, or `nil` for none.
    ///   - railOpacity: How strongly the rail is drawn, within 0...1.
    ///   - elevation: How far off the page the card sits.
    public init(rail: Color? = nil, railOpacity: Double = 1, elevation: Elevation = .card) {
        self.rail = rail
        self.railOpacity = railOpacity
        self.elevation = elevation
        freshness = nil
    }

    /// Creates a surface that expresses how much life a thought has left.
    ///
    /// The card loses its fill and its lift together as freshness runs out, so a thought about to
    /// be archived has visually almost rejoined the page it is printed on. Prefer this over the
    /// plain initialiser anywhere the surface belongs to a thought (ADR-0035).
    /// - Parameters:
    ///   - freshness: A value within 0...1.
    ///   - rail: A colour for the 3pt marker down the leading edge, or `nil` for none.
    ///   - railOpacity: How strongly the rail is drawn, within 0...1.
    public init(freshness: Double, rail: Color? = nil, railOpacity: Double = 1) {
        self.rail = rail
        self.railOpacity = railOpacity
        elevation = FreshnessStyle.elevation(for: freshness)
        self.freshness = freshness
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .fill(resolvedFill)
            .elevated(elevation, cornerRadius: Radius.card)
            .overlay(alignment: .leading) {
                if let rail {
                    Capsule()
                        .fill(rail)
                        .opacity(railOpacity)
                        .frame(width: 3)
                        // Clear of the corner radius at both ends, and close enough to the edge
                        // that it reads as part of the card rather than an item inside it.
                        .padding(.vertical, Spacing.regular)
                        .padding(.leading, Spacing.hairline)
                }
            }
    }

    /// The fill: the raised colour for a plain card, and a sinking one for a thought's card.
    private var resolvedFill: Color {
        guard let freshness else { return Palette.raised }
        return FreshnessStyle.cardFill(
            for: freshness,
            increasedContrast: contrast == .increased
        )
    }
}
