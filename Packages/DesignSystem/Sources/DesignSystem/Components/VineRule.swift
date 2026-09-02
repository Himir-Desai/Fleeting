import SwiftUI

/// A short vine of leaves along a line, marking a piece of writing that grew out of a fragment.
///
/// The sprout's grown-up sibling (ADR-0042). Where ``SproutMark`` says "this took root", a vine
/// says "this has been growing a while" — so it belongs on a write-up, which is a thought that has
/// been developed rather than merely kept.
public struct VineRule: View {
    private let leaves: Int
    private let tint: Color

    @State private var progress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the rule.
    /// - Parameters:
    ///   - leaves: How many leaves sit along it.
    ///   - tint: The stroke colour.
    public init(leaves: Int = 3, tint: Color = Palette.accentText) {
        self.leaves = max(leaves, 1)
        self.tint = tint
    }

    public var body: some View {
        Vine(leaves: leaves)
            .trim(from: 0, to: progress)
            .stroke(tint.opacity(0.55), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            .frame(height: 18)
            .onAppear {
                guard !reduceMotion else {
                    progress = 1
                    return
                }
                withAnimation(Motion.growth) { progress = 1 }
            }
            .accessibilityHidden(true)
    }
}

/// A horizontal stem with small leaves alternating above and below it.
private struct Vine: Shape {
    let leaves: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midline = rect.midY

        path.move(to: CGPoint(x: rect.minX, y: midline))
        path.addLine(to: CGPoint(x: rect.maxX, y: midline))

        // Leaves are spaced along the first two thirds, so the line trails off bare rather than
        // ending on a leaf and looking cropped.
        let span = rect.width * 0.66
        let step = span / CGFloat(leaves + 1)

        for index in 1 ... leaves {
            let stemX = rect.minX + step * CGFloat(index)
            let up = index.isMultiple(of: 2)
            let tipY = up ? midline - rect.height * 0.42 : midline + rect.height * 0.42
            // Leaves are wide relative to the line so they read as leaves rather than as kinks
            // in it. A fixed width, not a fraction: the rule stretches to its container, and a
            // proportional leaf would be a different shape on every screen it appeared on.
            let tipX = stemX + 9

            path.move(to: CGPoint(x: stemX, y: midline))
            path.addQuadCurve(
                to: CGPoint(x: tipX, y: tipY),
                control: CGPoint(x: stemX, y: tipY)
            )
            path.addQuadCurve(
                to: CGPoint(x: stemX, y: midline),
                control: CGPoint(x: tipX, y: midline)
            )
        }
        return path
    }
}
