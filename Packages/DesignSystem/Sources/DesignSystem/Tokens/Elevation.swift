import CoreGraphics

/// How far a surface sits off the page.
///
/// Expressed as a level rather than a shadow, because a shadow is only half the answer: on the
/// dark appearance a drop shadow is invisible against a near-black page, so the same level is
/// drawn as a hairline instead. `View.elevated(_:cornerRadius:)` is what resolves it (ADR-0022).
public enum Elevation: Sendable {
    /// Flush with the page. No shadow, no outline.
    case flat
    /// A thought row or a settings block: present, but not asking for attention.
    case card
    /// A review card, which is the only thing on its screen.
    case floating

    /// The shadow's blur radius in the light appearance.
    public var blur: CGFloat {
        switch self {
        case .flat: 0
        case .card: 6
        case .floating: 20
        }
    }

    /// How far the shadow falls below the surface, in points.
    public var offset: CGFloat {
        switch self {
        case .flat: 0
        case .card: 1
        case .floating: 6
        }
    }

    /// The shadow's opacity in the light appearance.
    public var shadowOpacity: Double {
        switch self {
        case .flat: 0
        case .card: 0.06
        case .floating: 0.12
        }
    }
}
