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

    /// Creates the surface.
    /// - Parameters:
    ///   - rail: A colour for the 3pt marker down the leading edge, or `nil` for none.
    ///   - railOpacity: How strongly the rail is drawn, within 0...1.
    ///   - elevation: How far off the page the card sits.
    public init(rail: Color? = nil, railOpacity: Double = 1, elevation: Elevation = .card) {
        self.rail = rail
        self.railOpacity = railOpacity
        self.elevation = elevation
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .fill(Palette.raised)
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
}
