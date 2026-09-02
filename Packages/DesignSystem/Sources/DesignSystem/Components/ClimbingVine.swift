import SwiftUI

/// A vine that climbs the edge of a page, as quiet furniture rather than a mark.
///
/// The capture screen is deliberately almost empty, and after the writing well was removed it read
/// less as paper than as a screen that had failed to load. This gives the page something growing
/// on it without putting anything in the way of the one thing that screen is for (ADR-0046).
///
/// Drawn at a low opacity and never interactive: it is the page's texture, not a control. It grows
/// once when the screen appears, then simply stays.
public struct ClimbingVine: View {
    private let height: CGFloat

    @State private var progress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the vine.
    /// - Parameter height: How tall a run to draw.
    public init(height: CGFloat = 200) {
        self.height = height
    }

    public var body: some View {
        ClimbingStem()
            .trim(from: 0, to: progress)
            .stroke(
                Palette.accentText.opacity(0.16),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
            .frame(width: 56, height: height)
            .onAppear {
                guard !reduceMotion else {
                    progress = 1
                    return
                }
                withAnimation(Motion.growth.delay(0.2)) { progress = 1 }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A tall stem that meanders upward, putting out a leaf every so often.
private struct ClimbingStem: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // The stem: two gentle curves, so it leans rather than snakes.
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.midX + width * 0.30, y: rect.maxY - height * 0.33),
            control2: CGPoint(x: rect.midX - width * 0.30, y: rect.minY + height * 0.33)
        )

        // Leaves at three heights, alternating sides, each a closed almond like the vine rule's.
        let stops: [(y: CGFloat, right: Bool)] = [
            (0.74, true), (0.50, false), (0.26, true)
        ]

        for stop in stops {
            let anchor = CGPoint(x: rect.midX, y: rect.minY + height * stop.y)
            let direction: CGFloat = stop.right ? 1 : -1
            let tip = CGPoint(
                x: anchor.x + direction * width * 0.42,
                y: anchor.y - height * 0.06
            )

            path.move(to: anchor)
            path.addQuadCurve(
                to: tip,
                control: CGPoint(x: anchor.x + direction * width * 0.12, y: anchor.y - height * 0.07)
            )
            path.addQuadCurve(
                to: anchor,
                control: CGPoint(x: anchor.x + direction * width * 0.30, y: anchor.y + height * 0.02)
            )
        }
        return path
    }
}
