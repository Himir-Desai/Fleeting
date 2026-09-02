import SwiftUI

/// A stem with a leaf, drawn as a line and grown rather than shown.
///
/// The app's one decorative gesture, and the only one that earns its place: a thing that grows is
/// the visual form of the app's own thesis. It marks the moments where a thought gains life — a
/// capture that reached storage, a review card kept, a habit's streak (ADR-0042).
///
/// Never load-bearing. It carries no information the surrounding text does not already state, so
/// under Reduce Motion it simply appears fully grown, and nothing waits on it either way.
public struct SproutMark: View {
    private let progress: Double
    private let tint: Color

    /// Creates the mark at a given stage of growth.
    /// - Parameters:
    ///   - progress: How far grown, within 0...1. Animate this from 0 to 1.
    ///   - tint: The stroke colour.
    public init(progress: Double, tint: Color = Palette.accentText) {
        self.progress = min(max(progress, 0), 1)
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            // The stem draws first and fastest, so the leaves have something to unfurl from.
            Stem()
                .trim(from: 0, to: stemProgress)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // Both leaves live in one path, so a single trim unfurls them in sequence: the right
            // one opens, then the left. Drawing them together looked like a shape appearing
            // rather than a plant growing.
            Leaf()
                .trim(from: 0, to: leafProgress)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .accessibilityHidden(true)
    }

    /// The stem is complete by 45% of the way through, leaving room for both leaves.
    private var stemProgress: Double {
        min(progress / 0.45, 1)
    }

    /// The leaves start only once the stem has something to hold them.
    private var leafProgress: Double {
        progress <= 0.25 ? 0 : (progress - 0.25) / 0.75
    }
}

/// The stem: a single curve leaning slightly, so it reads as grown rather than drawn with a ruler.
///
/// Rises from the bottom edge to just short of the top, staying near the centre so the leaves can
/// sit either side of it without the mark looking lopsided.
private struct Stem: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX + rect.width * 0.04, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.04, y: rect.minY + rect.height * 0.10),
            control: CGPoint(x: rect.midX + rect.width * 0.10, y: rect.midY)
        )
        return path
    }
}

/// Two leaves, one either side of the stem, each a pointed almond rather than a round blob.
///
/// A single leaf on one side read as the bowl of a lowercase "p". Two, opposed and pointed, is
/// unmistakably a seedling.
private struct Leaf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // The right leaf, rising away from the stem.
        let rightBase = CGPoint(x: rect.midX, y: rect.minY + height * 0.44)
        let rightTip = CGPoint(x: rect.midX + width * 0.40, y: rect.minY + height * 0.14)
        path.move(to: rightBase)
        path.addQuadCurve(
            to: rightTip,
            control: CGPoint(x: rect.midX + width * 0.10, y: rect.minY + height * 0.18)
        )
        path.addQuadCurve(
            to: rightBase,
            control: CGPoint(x: rect.midX + width * 0.30, y: rect.minY + height * 0.44)
        )

        // The left leaf, smaller and lower, so the mark grows rather than mirrors.
        let leftBase = CGPoint(x: rect.midX, y: rect.minY + height * 0.62)
        let leftTip = CGPoint(x: rect.midX - width * 0.34, y: rect.minY + height * 0.38)
        path.move(to: leftBase)
        path.addQuadCurve(
            to: leftTip,
            control: CGPoint(x: rect.midX - width * 0.08, y: rect.minY + height * 0.40)
        )
        path.addQuadCurve(
            to: leftBase,
            control: CGPoint(x: rect.midX - width * 0.26, y: rect.minY + height * 0.62)
        )
        return path
    }
}

#Preview {
    SproutMark(progress: 1)
        .frame(width: 44, height: 44)
        .padding()
}
