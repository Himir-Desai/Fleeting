import SwiftUI

/// A meter showing how much freshness a thought has left.
///
/// Reads as a proportion: a spent track behind, a tinted fill in front, and a tint that warms as
/// the fill runs out. It is the app's core mechanic made visible, so it is drawn at a weight that
/// survives a glance (ADR-0022).
public struct FreshnessMeter: View {
    private let freshness: Double
    private let thickness: CGFloat

    /// Creates the meter.
    /// - Parameters:
    ///   - freshness: A value within 0...1.
    ///   - thickness: How tall the meter is drawn. Defaults to 5pt.
    public init(freshness: Double, thickness: CGFloat = 5) {
        self.freshness = min(max(freshness, 0), 1)
        self.thickness = thickness
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(FreshnessStyle.track)
                Capsule()
                    .fill(FreshnessStyle.tint(for: freshness))
                    // Never narrower than it is tall: a thought at the very end of its life still
                    // shows a mark, rather than an empty track that could mean anything.
                    .frame(width: max(proxy.size.width * freshness, thickness))
            }
        }
        .frame(height: thickness)
        .motion(Motion.decay, value: freshness)
        .accessibilityHidden(true)
    }
}
